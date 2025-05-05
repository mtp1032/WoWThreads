import os
import shutil
import subprocess
import tempfile

# USAGE:
# copy py clone_wowheads_repo.py ..
# python clone_<file>_repo.py

# Define the GitHub repository URL
repo_url = "https://github.com/mtp1032/WoWThreads.git"

# Define the list of target directories
# Copies WoWTreads from _retail_dir to target dirs below
target_directories = [
#    r"C:\Program Files (x86)\World of Warcraft\_ptr_\Interface\AddOns",             # Retail PTR
    r"C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns",         # Cataclysm classic
    r"C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns",    # MOP classic beta
    r"C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns",    # Classic Vanilla
    r"G:\My Drive\Addons-github-clones"
]   
def copy_directory(src, dest, ignore_dirs=None):
    """Copy directory while ignoring specified subdirectories."""
    if ignore_dirs is None:
        ignore_dirs = []

    for item in os.listdir(src):
        source = os.path.join(src, item)
        destination = os.path.join(dest, item)
        
        if os.path.isdir(source):
            if item not in ignore_dirs:
                try:
                    shutil.copytree(source, destination, dirs_exist_ok=True)
                except Exception as e:
                    print(f"Error copying directory {source} to {destination}: {e}")
        else:
            try:
                shutil.copy2(source, destination)
            except Exception as e:
                print(f"Error copying file {source} to {destination}: {e}")

def clone_repository(repo_url, destination):
    """Clones the repository to the specified destination."""
    try:
        subprocess.run(["git", "clone", repo_url, destination], check=True)
        print(f"Repository cloned to {destination}")
    except subprocess.CalledProcessError as e:
        print(f"Error cloning repository: {e}")
        raise

# Main script execution
with tempfile.TemporaryDirectory() as temp_dir:
    # Clone the repository into the temporary directory
    clone_repository(repo_url, temp_dir)

    # Loop through each target directory
    for target_dir in target_directories:
        # Define the path to the WoWThreads subdirectory
        metrics_dir = os.path.join(target_dir, "WoWThreads")

        # Ensure the target directory exists
        try:
            os.makedirs(metrics_dir, exist_ok=True)
        except OSError as e:
            print(f"Error creating directory {metrics_dir}: {e}")
            continue

        # Remove existing non-Git files in the WoWThreads directory
        if os.path.exists(metrics_dir):
            try:
                for item in os.listdir(metrics_dir):
                    item_path = os.path.join(metrics_dir, item)
                    if os.path.isdir(item_path) and item != ".git":
                        shutil.rmtree(item_path)
                    elif os.path.isfile(item_path):
                        os.remove(item_path)
            except PermissionError as e:
                print(f"PermissionError: {e}")
                print("Skipping deletion of some files due to permissions issues.")
            except Exception as e:
                print(f"Error cleaning directory {metrics_dir}: {e}")
                continue

        # Copy the contents of the cloned repository to the WoWThreads directory,
        # excluding the .git directory
        copy_directory(temp_dir, metrics_dir, ignore_dirs=[".git"])

# The temporary directory is automatically cleaned up when the context exits
