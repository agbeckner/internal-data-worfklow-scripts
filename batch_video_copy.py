import os
import shutil

# Set the source directory (change this to your subdirectory path)
source_dir = "path/to/your/subdirectory"

# Set the destination directory (change this to your desktop folder)
destination_dir = os.path.expanduser("~/Desktop/Filtered_Files")

# Create the destination folder if it doesn't exist
os.makedirs(destination_dir, exist_ok=True)

# Define common video file extensions
file_extensions = {".mp4", ".avi", ".mov", ".mkv", ".flv", ".wmv"}

# Define the keyword to search for in filenames
search_keyword = "play"  # Change this to any keyword you want

# Search for and move matching files
for root, _, files in os.walk(source_dir):
    for file in files:
        if search_keyword.lower() in file.lower() and any(file.lower().endswith(ext) for ext in file_extensions):
            source_path = os.path.join(root, file)
            destination_path = os.path.join(destination_dir, file)
            
            # Move the file
            shutil.move(source_path, destination_path)
            print(f"Moved: {source_path} -> {destination_path}")

print("Transfer complete.")
