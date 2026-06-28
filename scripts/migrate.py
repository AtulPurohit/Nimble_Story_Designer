import os
import re

source_dir = "/Users/atulpurohit/Desktop/Writco/FlutterProject2026/Storito App"
target_dir = "/Users/atulpurohit/Desktop/Writco/FlutterProject2026/Nimble_Story"

viewer_src = os.path.join(source_dir, "lib/features/nimble/nimble_viewer_screen.dart")
creator_src = os.path.join(source_dir, "lib/features/nimble/nimble_creator_screen.dart")

viewer_dest = os.path.join(target_dir, "lib/src/screens/story_viewer_screen.dart")
creator_dest = os.path.join(target_dir, "lib/src/screens/story_creator_screen.dart")

# Ensure target directories exist
os.makedirs(os.path.dirname(viewer_dest), exist_ok=True)

# Copy files
with open(viewer_src, 'r') as f:
    viewer_code = f.read()

with open(creator_src, 'r') as f:
    creator_code = f.read()

print("Files read successfully!")
print("Viewer code length:", len(viewer_code))
print("Creator code length:", len(creator_code))
