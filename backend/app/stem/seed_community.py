"""Seed Phase 9-14 data: forum posts, announcements, study groups.

Idempotent — safe to run multiple times.  Follows the same pattern as
seed_expanded.py: helper functions with skip-if-exists logic, orchestrated
by a single commit at the end.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.engine import async_session
from app.models.models import User
from app.models.stem import (
    STEMAnnouncement,
    STEMForumAnswer,
    STEMForumPost,
    STEMForumVote,
    STEMGroupMember,
    STEMGroupMessage,
    STEMStudyGroup,
)

# ── Data ──────────────────────────────────────────────────────────────

FORUM_POSTS = [
    {
        "title": "How do I solve simultaneous equations?",
        "body": (
            "I'm struggling with systems of linear equations. "
            "Can someone explain the substitution method step by step?"
        ),
        "subject_slug": "mathematics",
        "is_question": True,
    },
    {
        "title": "Newton's Third Law — common misconception",
        "body": (
            "A lot of students think the forces cancel out. "
            "They don't — they act on different bodies!"
        ),
        "subject_slug": "physics",
        "is_question": True,
    },
    {
        "title": "Tips for the chemistry practical exam",
        "body": (
            "Here are some tips for the titration practical: "
            "1) Rinse the burette with the titrant, not water. "
            "2) Use a white tile for colour change detection."
        ),
        "subject_slug": "chemistry",
        "is_question": False,
    },
    {
        "title": "What is the difference between mitosis and meiosis?",
        "body": (
            "I keep confusing the two. Can someone give a clear "
            "comparison with diagrams?"
        ),
        "subject_slug": "biology",
        "is_question": True,
    },
    {
        "title": "Recursion vs Iteration — when to use which?",
        "body": (
            "I understand both concepts but I'm never sure when "
            "to pick one over the other. Any advice?"
        ),
        "subject_slug": "computer_science",
        "is_question": True,
    },
    {
        "title": "Best resources for MSCE revision",
        "body": (
            "I've compiled a list of free online resources for "
            "MSCE revision. Check them out and add your own!"
        ),
        "subject_slug": None,
        "is_question": False,
    },
]

ANNOUNCEMENTS = [
    {
        "title": "Mid-semester exams starting next week",
        "body": (
            "Mid-semester examinations for all Year 2 students "
            "will commence on Monday. Please check your timetable."
        ),
        "subject_slug": None,
        "priority": "high",
        "is_pinned": True,
        "target_audience": "all",
    },
    {
        "title": "New Computer Science lab hours",
        "body": (
            "The CS lab will now be open from 8 AM to 8 PM on "
            "weekdays to support your coursework."
        ),
        "subject_slug": "computer_science",
        "priority": "normal",
        "is_pinned": False,
        "target_audience": "students",
    },
    {
        "title": "Guest lecture: AI in Agriculture",
        "body": (
            "Dr. Kamwendo from LUANAR will give a guest lecture "
            "on AI applications in Malawian agriculture this Friday."
        ),
        "subject_slug": "computer_science",
        "priority": "normal",
        "is_pinned": False,
        "target_audience": "all",
    },
    {
        "title": "Assignment 3 deadline extended",
        "body": (
            "Due to the network outage, the deadline for "
            "Assignment 3 has been extended to Friday 5 PM."
        ),
        "subject_slug": "computer_science",
        "priority": "low",
        "is_pinned": False,
        "target_audience": "students",
    },
]

STUDY_GROUPS = [
    {
        "name": "Mathematics Revision Group",
        "description": "Weekly revision sessions for Year 2 maths.",
        "subject_slug": "mathematics",
    },
    {
        "name": "Physics Lab Partners",
        "description": "Coordinate lab sessions and share reports.",
        "subject_slug": "physics",
    },
    {
        "name": "CS Study Circle",
        "description": "Algorithms, data structures, and exam prep.",
        "subject_slug": "computer_science",
    },
]

GROUP_MESSAGES = [
    {"message": "Welcome to the group!"},
    {"message": "Shall we meet tomorrow at 3 PM?"},
    {"message": "I've uploaded my notes to the vault."},
]


# ── Helpers ───────────────────────────────────────────────────────────


async def _seed_forum_posts(db: AsyncSession) -> dict:
    existing = {row[0] for row in await db.execute(select(STEMForumPost.title))}
    students = (
        (await db.execute(select(User).where(User.role == "student").limit(3)))
        .scalars()
        .all()
    )
    if not students:
        return {"posts": 0, "answers": 0, "votes": 0}

    posts_added = 0
    answers_added = 0
    votes_added = 0

    for i, data in enumerate(FORUM_POSTS):
        if data["title"] in existing:
            continue
        author = students[i % len(students)]
        post = STEMForumPost(
            user_id=author.id,
            title=data["title"],
            body=data["body"],
            subject_slug=data["subject_slug"],
            is_question=data["is_question"],
        )
        db.add(post)
        posts_added += 1

    await db.flush()

    if posts_added:
        all_posts = (await db.execute(select(STEMForumPost))).scalars().all()
        for post in all_posts[:2]:
            if any(a.body.startswith("Here's the answer") for a in []):
                continue
            responder = (
                students[1]
                if len(students) > 1 and post.user_id == students[0].id
                else students[0]
            )
            answer = STEMForumAnswer(
                post_id=post.id,
                user_id=responder.id,
                body="Here's the answer: try setting x = y + 2 first.",
            )
            db.add(answer)
            answers_added += 1

        await db.flush()

        existing_votes = set(
            (row[0], row[1])
            for row in await db.execute(
                select(STEMForumVote.user_id, STEMForumVote.post_id)
            )
        )
        for post in all_posts[:3]:
            if (students[0].id, post.id) not in existing_votes:
                vote = STEMForumVote(
                    user_id=students[0].id,
                    post_id=post.id,
                    value=1,
                )
                db.add(vote)
                votes_added += 1

    return {"posts": posts_added, "answers": answers_added, "votes": votes_added}


async def _seed_announcements(db: AsyncSession) -> int:
    existing = {row[0] for row in await db.execute(select(STEMAnnouncement.title))}
    lecturer = (
        (await db.execute(select(User).where(User.role == "lecturer").limit(1)))
        .scalars()
        .first()
    )
    if not lecturer:
        return 0

    added = 0
    for data in ANNOUNCEMENTS:
        if data["title"] in existing:
            continue
        ann = STEMAnnouncement(
            author_id=lecturer.id,
            title=data["title"],
            body=data["body"],
            subject_slug=data["subject_slug"],
            priority=data["priority"],
            is_pinned=data["is_pinned"],
            target_audience=data["target_audience"],
        )
        db.add(ann)
        added += 1
    return added


async def _seed_study_groups(db: AsyncSession) -> dict:
    existing = {row[0] for row in await db.execute(select(STEMStudyGroup.name))}
    students = (
        (await db.execute(select(User).where(User.role == "student").limit(3)))
        .scalars()
        .all()
    )
    if not students:
        return {"groups": 0, "members": 0, "messages": 0}

    groups_added = 0
    members_added = 0
    messages_added = 0

    for i, data in enumerate(STUDY_GROUPS):
        if data["name"] in existing:
            continue
        creator = students[i % len(students)]
        group = STEMStudyGroup(
            name=data["name"],
            description=data["description"],
            subject_slug=data["subject_slug"],
            creator_id=creator.id,
        )
        db.add(group)
        groups_added += 1

    await db.flush()

    all_groups = (await db.execute(select(STEMStudyGroup))).scalars().all()
    for group in all_groups[:3]:
        existing_members = {
            row[0]
            for row in await db.execute(
                select(STEMGroupMember.user_id).where(
                    STEMGroupMember.group_id == group.id
                )
            )
        }
        if group.creator_id not in existing_members:
            db.add(
                STEMGroupMember(
                    group_id=group.id,
                    user_id=group.creator_id,
                    role="owner",
                )
            )
            members_added += 1
        for student in students[:2]:
            if student.id not in existing_members and student.id != group.creator_id:
                db.add(
                    STEMGroupMember(
                        group_id=group.id,
                        user_id=student.id,
                        role="member",
                    )
                )
                members_added += 1

    await db.flush()

    for group in all_groups[:2]:
        msg_count = (
            (
                await db.execute(
                    select(STEMGroupMessage).where(
                        STEMGroupMessage.group_id == group.id
                    )
                )
            )
            .scalars()
            .all()
        )
        if not msg_count:
            for j, msg_data in enumerate(GROUP_MESSAGES):
                db.add(
                    STEMGroupMessage(
                        group_id=group.id,
                        user_id=group.creator_id,
                        message=msg_data["message"],
                    )
                )
                messages_added += 1

    return {
        "groups": groups_added,
        "members": members_added,
        "messages": messages_added,
    }


# ── Orchestrator ──────────────────────────────────────────────────────


async def seed_community():
    """Seed forum, announcements, and study group data."""
    async with async_session() as db:
        try:
            results = {}
            results["forum"] = await _seed_forum_posts(db)
            results["announcements"] = await _seed_announcements(db)
            results["study_groups"] = await _seed_study_groups(db)
            await db.commit()
            print(f"[seed_community] {results}")
            return results
        except Exception:
            await db.rollback()
            raise


if __name__ == "__main__":
    import asyncio

    asyncio.run(seed_community())
