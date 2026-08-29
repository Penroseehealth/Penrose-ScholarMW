import asyncio
import sys
sys.path.insert(0, ".")
from app.mathematics.seed_math_syllabus import seed_math_syllabus

async def main():
    try:
        await seed_math_syllabus()
        print("Seed completed successfully")
    except Exception as e:
        print(f"Seed failed: {e}")
        import traceback
        traceback.print_exc()

asyncio.run(main())
