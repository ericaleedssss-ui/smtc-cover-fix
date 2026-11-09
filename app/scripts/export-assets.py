"""Export the navigation and lettering data used by the 2D app."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
output = root / "output/resources"
output.mkdir(parents=True, exist_ok=True)
for name in ["slots.json"]:
    (output / name).write_bytes((root / "Resources" / name).read_bytes())
print(output)
