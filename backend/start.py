#!/usr/bin/env python3
"""Start the Penrose ScholarMW backend server."""

import uvicorn

if __name__ == "__main__":
    print("=" * 50)
    print("  Penrose ScholarMW — Starting server...")
    print("  http://localhost:8000")
    print("  API docs: http://localhost:8000/docs")
    print("=" * 50)
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
