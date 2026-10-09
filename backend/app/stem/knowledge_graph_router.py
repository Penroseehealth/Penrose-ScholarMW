from collections import defaultdict, deque

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.database.engine import get_db
from app.models.stem import (
    KnowledgeGraphEdge,
    STEMConcept,
    STEMDiscipline,
    STEMSubject,
    STEMSubtopic,
    STEMTopic,
)

router = APIRouter(prefix="/stem", tags=["STEM Intelligence"])


class ConceptBrief(BaseModel):
    id: int
    title: str
    description: str | None


class EdgeResponse(BaseModel):
    id: int
    source_concept: ConceptBrief
    target_concept: ConceptBrief
    relationship_type: str
    description: str | None
    weight: float


class ConnectedConceptResponse(BaseModel):
    concept: ConceptBrief
    edges: list[EdgeResponse]


class PathSegment(BaseModel):
    concept: ConceptBrief
    edge_type: str | None = None


class ShortestPathResponse(BaseModel):
    source: ConceptBrief
    target: ConceptBrief
    path: list[PathSegment]
    length: int


class SubjectEdgeCount(BaseModel):
    subject_slug: str
    subject_title: str
    edge_count: int


class ConceptEdgeCount(BaseModel):
    concept_id: int
    concept_title: str
    edge_count: int


class KnowledgeGraphStats(BaseModel):
    total_edges: int
    edges_per_subject: list[SubjectEdgeCount]
    most_connected_concepts: list[ConceptEdgeCount]


def _concept_brief(c: STEMConcept) -> ConceptBrief:
    return ConceptBrief(id=c.id, title=c.title, description=c.description)


def _edge_response(edge: KnowledgeGraphEdge) -> EdgeResponse:
    return EdgeResponse(
        id=edge.id,
        source_concept=_concept_brief(edge.source_concept),
        target_concept=_concept_brief(edge.target_concept),
        relationship_type=edge.relationship_type,
        description=edge.description,
        weight=edge.weight,
    )


@router.get("/knowledge-graph/subject/{slug}", response_model=list[EdgeResponse])
async def get_edges_for_subject(slug: str, db: AsyncSession = Depends(get_db)):
    subject_result = await db.execute(
        select(STEMSubject).where(STEMSubject.subject_slug == slug)
    )
    subject = subject_result.scalar_one_or_none()
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found"
        )

    concept_ids_result = await db.execute(
        select(STEMConcept.id)
        .join(STEMSubtopic, STEMSubtopic.id == STEMConcept.subtopic_id)
        .join(STEMTopic, STEMTopic.id == STEMSubtopic.topic_id)
        .join(STEMDiscipline, STEMDiscipline.id == STEMTopic.discipline_id)
        .where(STEMDiscipline.subject_id == subject.id)
    )
    concept_ids = set(concept_ids_result.scalars().all())
    if not concept_ids:
        return []

    edges_result = await db.execute(
        select(KnowledgeGraphEdge)
        .options(
            joinedload(KnowledgeGraphEdge.source_concept),
            joinedload(KnowledgeGraphEdge.target_concept),
        )
        .where(
            or_(
                KnowledgeGraphEdge.source_concept_id.in_(concept_ids),
                KnowledgeGraphEdge.target_concept_id.in_(concept_ids),
            )
        )
    )
    edges = edges_result.unique().scalars().all()
    return [_edge_response(e) for e in edges]


@router.get(
    "/knowledge-graph/concept/{concept_id}",
    response_model=list[ConnectedConceptResponse],
)
async def get_connected_concepts(concept_id: int, db: AsyncSession = Depends(get_db)):
    concept_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == concept_id)
    )
    if not concept_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Concept not found"
        )

    edges_result = await db.execute(
        select(KnowledgeGraphEdge)
        .options(
            joinedload(KnowledgeGraphEdge.source_concept),
            joinedload(KnowledgeGraphEdge.target_concept),
        )
        .where(
            or_(
                KnowledgeGraphEdge.source_concept_id == concept_id,
                KnowledgeGraphEdge.target_concept_id == concept_id,
            )
        )
    )
    edges = edges_result.unique().scalars().all()

    connected: dict[int, list[KnowledgeGraphEdge]] = defaultdict(list)
    for edge in edges:
        other_id = (
            edge.target_concept_id
            if edge.source_concept_id == concept_id
            else edge.source_concept_id
        )
        connected[other_id].append(edge)

    results: list[ConnectedConceptResponse] = []
    for other_id, conn_edges in connected.items():
        other = (
            conn_edges[0].target_concept
            if conn_edges[0].source_concept_id == concept_id
            else conn_edges[0].source_concept
        )
        results.append(
            ConnectedConceptResponse(
                concept=_concept_brief(other),
                edges=[_edge_response(e) for e in conn_edges],
            )
        )
    return results


@router.get(
    "/knowledge-graph/paths/{source_id}/{target_id}",
    response_model=ShortestPathResponse,
)
async def shortest_path(
    source_id: int, target_id: int, db: AsyncSession = Depends(get_db)
):
    source_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == source_id)
    )
    source_concept = source_result.scalar_one_or_none()
    if not source_concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Source concept not found"
        )

    target_result = await db.execute(
        select(STEMConcept).where(STEMConcept.id == target_id)
    )
    target_concept = target_result.scalar_one_or_none()
    if not target_concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Target concept not found"
        )

    if source_id == target_id:
        return ShortestPathResponse(
            source=_concept_brief(source_concept),
            target=_concept_brief(target_concept),
            path=[PathSegment(concept=_concept_brief(source_concept))],
            length=0,
        )

    all_edges_result = await db.execute(
        select(KnowledgeGraphEdge).options(
            joinedload(KnowledgeGraphEdge.source_concept),
            joinedload(KnowledgeGraphEdge.target_concept),
        )
    )
    all_edges = all_edges_result.unique().scalars().all()

    adjacency: dict[int, list[tuple[int, str, int]]] = defaultdict(list)
    edge_map: dict[int, STEMConcept] = {}
    for edge in all_edges:
        adjacency[edge.source_concept_id].append(
            (edge.target_concept_id, edge.relationship_type, edge.id)
        )
        adjacency[edge.target_concept_id].append(
            (edge.source_concept_id, edge.relationship_type, edge.id)
        )
        edge_map[edge.source_concept_id] = edge.source_concept
        edge_map[edge.target_concept_id] = edge.target_concept

    visited: dict[int, int | None] = {source_id: None}
    edge_used: dict[int, str | None] = {source_id: None}
    queue: deque[int] = deque([source_id])
    max_depth = 5

    current_depth = 0
    nodes_at_depth = len(queue)

    while queue and current_depth < max_depth:
        current = queue.popleft()
        nodes_at_depth -= 1

        for neighbor_id, rel_type, _ in adjacency.get(current, []):
            if neighbor_id not in visited:
                visited[neighbor_id] = current
                edge_used[neighbor_id] = rel_type
                queue.append(neighbor_id)

                if neighbor_id == target_id:
                    path_segments: list[PathSegment] = []
                    node = target_id
                    while node is not None:
                        parent = visited[node]
                        concept_result = await db.execute(
                            select(STEMConcept).where(STEMConcept.id == node)
                        )
                        concept = concept_result.scalar_one_or_none()
                        seg = PathSegment(
                            concept=_concept_brief(concept),
                            edge_type=edge_used.get(node),
                        )
                        path_segments.append(seg)
                        node = parent
                    path_segments.reverse()
                    return ShortestPathResponse(
                        source=_concept_brief(source_concept),
                        target=_concept_brief(target_concept),
                        path=path_segments,
                        length=len(path_segments) - 1,
                    )

        if nodes_at_depth == 0:
            current_depth += 1
            nodes_at_depth = len(queue)

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"No path found between concepts within depth {max_depth}",
    )


@router.get("/knowledge-graph/stats", response_model=KnowledgeGraphStats)
async def get_knowledge_graph_stats(db: AsyncSession = Depends(get_db)):
    total_result = await db.execute(
        select(func.count()).select_from(KnowledgeGraphEdge)
    )
    total_edges = total_result.scalar() or 0

    subject_edges_result = await db.execute(
        select(
            STEMSubject.subject_slug,
            STEMSubject.title,
            func.count(KnowledgeGraphEdge.id).label("cnt"),
        )
        .join(STEMDiscipline, STEMDiscipline.subject_id == STEMSubject.id)
        .join(STEMTopic, STEMTopic.discipline_id == STEMDiscipline.id)
        .join(STEMSubtopic, STEMSubtopic.topic_id == STEMTopic.id)
        .join(STEMConcept, STEMConcept.subtopic_id == STEMSubtopic.id)
        .outerjoin(
            KnowledgeGraphEdge,
            or_(
                KnowledgeGraphEdge.source_concept_id == STEMConcept.id,
                KnowledgeGraphEdge.target_concept_id == STEMConcept.id,
            ),
        )
        .group_by(STEMSubject.id)
    )
    edges_per_subject = [
        SubjectEdgeCount(subject_slug=row[0], subject_title=row[1], edge_count=row[2])
        for row in subject_edges_result.all()
    ]

    concept_edge_result = await db.execute(
        select(
            STEMConcept.id,
            STEMConcept.title,
            func.count(KnowledgeGraphEdge.id).label("cnt"),
        )
        .outerjoin(
            KnowledgeGraphEdge,
            or_(
                KnowledgeGraphEdge.source_concept_id == STEMConcept.id,
                KnowledgeGraphEdge.target_concept_id == STEMConcept.id,
            ),
        )
        .group_by(STEMConcept.id)
        .order_by(func.count(KnowledgeGraphEdge.id).desc())
        .limit(10)
    )
    most_connected = [
        ConceptEdgeCount(concept_id=row[0], concept_title=row[1], edge_count=row[2])
        for row in concept_edge_result.all()
    ]

    return KnowledgeGraphStats(
        total_edges=total_edges,
        edges_per_subject=edges_per_subject,
        most_connected_concepts=most_connected,
    )
