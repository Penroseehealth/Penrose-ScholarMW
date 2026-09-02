import asyncio
from app.languages.expand_hsk1 import expand_hsk1
async def main():
    await expand_hsk1()
    print("EXPAND_DONE")
asyncio.run(main())
