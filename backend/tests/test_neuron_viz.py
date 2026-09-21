import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

# Import-register the biology_viz ORM models so `Base.metadata.create_all` in
# conftest creates their tables before the API tests run.
import app.models.biology_viz  # noqa: F401

from app.biology_viz.engine import build_spec
from app.biology_viz.specs import build_neuron_spec
from tests.conftest import auth_header


def test_build_neuron_spec_includes_synapse_structures():
    spec = build_neuron_spec()
    ids = {s.id for s in spec.structures}
    assert spec.kind == "neuron"
    assert spec.app == "neuron"
    for required in (
        "soma",
        "nucleus",
        "dendrites",
        "axon",
        "myelin_sheath",
        "nodes_of_ranvier",
        "axon_terminal",
        "synaptic_cleft",
        "postsynaptic_membrane",
        "synaptic_vesicles",
        "receptors",
        "neurotransmitter",
    ):
        assert required in ids
    assert spec.labels_shown is True


def test_build_neuron_spec_exclude_structure():
    spec = build_neuron_spec(exclude={"myelin sheath"})
    by_id = {s.id: s for s in spec.structures}
    assert by_id["myelin_sheath"].present is False
    assert by_id["axon"].present is True


@pytest.mark.asyncio
async def test_neuron_prompt_resolves_to_neuron_app(db_session: AsyncSession):
    spec, detected = await build_spec(
        db_session, "Show how two neurons communicate across a synapse"
    )
    assert detected.app == "neuron"
    assert spec.kind == "neuron"
    assert any(s.id == "synaptic_cleft" for s in spec.structures)


@pytest.mark.asyncio
async def test_synaptic_transmission_prompt_resolves_to_neuron(
    db_session: AsyncSession,
):
    spec, detected = await build_spec(db_session, "Explain synaptic transmission")
    assert detected.app == "neuron"
    assert spec.kind == "neuron"


@pytest.mark.asyncio
async def test_neuron_without_myelin_sheath_excludes_it(db_session: AsyncSession):
    spec, detected = await build_spec(
        db_session, "Draw a neuron without a myelin sheath"
    )
    assert detected.app == "neuron"
    by_id = {s.id: s for s in spec.structures}
    assert by_id["myelin_sheath"].present is False
    assert by_id["nodes_of_ranvier"].present is True


@pytest.mark.asyncio
async def test_neuron_save_endpoint(client: AsyncClient, student_user, student_token):
    response = await client.post(
        "/api/v1/biology/diagrams/save",
        headers=auth_header(student_token),
        json={"prompt": "Show how two neurons communicate"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["app"] == "neuron"
    spec = data["spec"]
    assert spec["kind"] == "neuron"
    structure_ids = {s["id"] for s in spec["structures"]}
    assert "soma" in structure_ids
    assert "synaptic_cleft" in structure_ids
