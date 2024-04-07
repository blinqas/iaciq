import os
import yaml
import subprocess
from collections import defaultdict, deque
import argparse
import json
import logging

# Function to set up logging with the specified level
def setup_logging(level):
    numeric_level = getattr(logging, level.upper(), None)
    if not isinstance(numeric_level, int):
        raise ValueError(f'Invalid log level: {level}')
    logging.basicConfig(level=numeric_level, format='%(asctime)s - %(levelname)s - %(message)s')

import subprocess

def run_git_command(command):
    """Executes a Git command and returns its output, printing errors if they occur."""
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True, cwd=find_git_root())
        return result.stdout.strip().split('\n')
    except subprocess.CalledProcessError as e:
        logging.error(f"Error executing command '{' '.join(command)}': {e}\nSTDERR: {e.stderr}")
        exit(1)
        
def get_current_git_ref():
    """Returns the current Git reference."""
    return run_git_command(['git', 'rev-parse', 'HEAD'])[0]

def checkout_git_ref(git_ref):
    """Checkouts a specific git_ref."""
    run_git_command(['git', 'checkout', git_ref])

def restore_git_ref(original_ref):
    """Restores to the original Git reference."""
    checkout_git_ref(original_ref)
        
def find_folders_with_metadata(repo_root, meta_files):
    """Finds all folders within the repo that contain an iaciq file."""
    folders_with_metadata = []
    possible_filenames = meta_files
    
    try:
        for root, dirs, files in os.walk(repo_root):
            # Check if any of the possible filenames exist in the current directory's files
            if any(filename in files for filename in possible_filenames):
                folders_with_metadata.append(root)
    except Exception as e:
        logging.error(f"Error finding folders with metadata: {e}")
        exit(1)

    return folders_with_metadata


def find_git_root():
    """Finds the Git repository root directory."""
    try:
        result = subprocess.run(['git', 'rev-parse', '--show-toplevel'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        logging.error(f"Error finding Git root directory: {e.stderr.strip()}")
        exit(1)

def get_changed_paths_since_git_ref(git_ref):
    """Finds changed paths since a given git reference, focusing on distinct folders."""
    repo_root = find_git_root()

    original_ref = get_current_git_ref()  # Store the original Git reference
    logging.debug(f"Original Git reference: {original_ref}")

    try:
        checkout_git_ref(git_ref)  # Checkout the specified git_ref
        logging.debug(f"Checked out {git_ref}")
        # Place your operations here that require git_ref to be checked out

    finally:
        restore_git_ref(original_ref)  # Always ensure we return to the original reference
        logging.debug(f"Restored to original Git reference: {original_ref}")

    # Get the changed files
    cmd = ['git', 'diff', f'{git_ref}', '--name-only']
    changed_files = run_git_command(cmd)

    # Convert file paths to their containing folder paths and ensure uniqueness
    changed_folders = {os.path.dirname(os.path.join(repo_root, path)) for path in changed_files}
    return changed_folders


def find_metadata_files(folder, meta_files):
    """Searches for an iaciq file with various naming conventions."""
    possible_filenames = meta_files
    for filename in possible_filenames:
        filepath = os.path.join(folder, filename)
        if os.path.isfile(filepath):
            return filepath
    return None

def construct_dependency_graph(folders_with_metadata, meta_files):
    """Constructs a dependency graph from iaciq files within specified folders, including iaciq content."""
    dependency_graph = {}
    action_content = {}
    repo_root = find_git_root()

    for folder in folders_with_metadata:
        action_file_path = find_metadata_files(folder, meta_files)
        if action_file_path:
            content = read_metadata_files(action_file_path)
            if content.get('depends_on') == "None" or content.get('depends_on') is None:
                dependencies = []
            else:
                dependencies = content.get('depends_on', [])
                if isinstance(dependencies, str):  # Checking if mistakenly interpreted as a single string
                    dependencies = [dependencies]
            abs_dependencies = [os.path.join(repo_root, dep) for dep in dependencies]
            dependency_graph[folder] = abs_dependencies

            # Check for job_name and set it if not present
            if 'job_name' not in content:
                content['job_name'] = os.path.basename(folder)
            action_content[folder] = content
        else:
            dependency_graph[folder] = []

    return dependency_graph, action_content

def read_metadata_files(file_path):
    """Reads a YAML file and returns its content, handling exceptions."""
    try:
        with open(file_path, 'r') as file:
            return yaml.safe_load(file)
    except yaml.YAMLError as e:
        logging.error(f"Error reading YAML file at {file_path}: {e}")
        return None

def get_reverse_dependency_graph(dependency_graph):
    """Creates a reverse dependency graph for easy lookup of dependents."""
    reverse_dependency_graph = defaultdict(set)
    try:
        for folder, dependencies in dependency_graph.items():
            for dep in dependencies:
                reverse_dependency_graph[dep].add(folder)
        return reverse_dependency_graph
    except Exception as e:
        logging.error(f"Error creating reverse dependency graph: {e}")
        exit(1)

def find_folders_needing_processing(updated_folders, dependency_graph, folders_with_metadata):
    """
    Identifies all folders that need to be processed based on being updated directly or by being
    dependent on updated folders, directly or through a chain of dependencies.
    """
    
    # Initialize with folders directly updated and also listed in folders_with_metadata
    try:
        folders_to_process = set(f for f in updated_folders if f in folders_with_metadata)
    except Exception as e:
        logging.error(f"Error finding folders needing processing: {e}")
        exit(1)
    
    # Create a reverse dependency graph for easy lookup of dependents
    reverse_dependency_graph = get_reverse_dependency_graph(dependency_graph)

    # Use a queue to manage recursive inclusion of dependent folders
    try:
        queue = deque(folders_to_process)
        while queue:
            current_folder = queue.popleft()
            for dependent in reverse_dependency_graph[current_folder]:
                if dependent in folders_with_metadata and dependent not in folders_to_process:
                    folders_to_process.add(dependent)
                    queue.append(dependent)
    except Exception as e:
        logging.error(f"Error finding folders needing processing: {e}")
        exit(1)

    return folders_to_process

def calculate_concurrency_groupsxx(dependency_graph, folders_to_process):
    """Calculates concurrency groups for processing."""
    concurrency_groups = defaultdict(list)
    folder_to_group = {}
    unprocessed_folders = set(folders_to_process)

    # Track dependencies within folders_to_process to manage group assignment
    try:        
        internal_dependencies = {folder: [dep for dep in deps if dep in folders_to_process]
                                 for folder, deps in dependency_graph.items() if folder in folders_to_process}
    except Exception as e:
        logging.error(f"Error calculating internal_dependencies: {e}")
        exit(1)

    group_number = 0

    try:
        while unprocessed_folders:
            group_number += 1  # Start with group 1 and increment
            current_group = []
            
            # Identify folders for the current group
            for folder in list(unprocessed_folders):  # List to copy because we're modifying the set during iteration
                # A folder is ready if it has no remaining dependencies not already processed
                if not any(dep in unprocessed_folders for dep in internal_dependencies.get(folder, [])):
                    current_group.append(folder)
                    folder_to_group[folder] = group_number

            # Update groups and processed tracking
            for folder in current_group:
                concurrency_groups[f'group{group_number}'].append(folder)
                unprocessed_folders.remove(folder)

            # If no progress is made, it indicates a cycle or logic error
            if not current_group:
                raise Exception("Unable to resolve dependencies into groups - potential cycle detected.")
        return dict(concurrency_groups)
    except Exception as e:
        logging.error(f"Error calculating concurrency groups: {e}")
        exit(1)

def calculate_concurrency_groups(dependency_graph, folders_to_process):
    """Calculates concurrency groups for processing."""
    concurrency_groups = defaultdict(list)
    folder_to_group = {}
    unprocessed_folders = set(folders_to_process)

    # Added initialization to ensure folders without dependencies are also considered
    no_dependency_folders = {
        folder for folder, deps in dependency_graph.items()
        if not deps and folder in folders_to_process
    }

    group_number = 0

    # Assign folders without dependencies to the first group(s)
    if no_dependency_folders:
        group_number += 1
        for folder in no_dependency_folders:
            concurrency_groups[f'group{group_number}'].append(folder)
            folder_to_group[folder] = group_number
            unprocessed_folders.remove(folder)

    try:
        while unprocessed_folders:
            # Remaining group number handling
            group_number += 1
            current_group = []

            # Identify folders for the current group
            for folder in list(unprocessed_folders):  
                if not any(dep in unprocessed_folders for dep in dependency_graph.get(folder, [])):
                    current_group.append(folder)
                    folder_to_group[folder] = group_number

            for folder in current_group:
                concurrency_groups[f'group{group_number}'].append(folder)
                unprocessed_folders.remove(folder)

            if not current_group:
                raise Exception("Unable to resolve dependencies into groups - potential cycle detected.")

        return dict(concurrency_groups)
    except Exception as e:
        logging.error(f"Error calculating concurrency groups: {e}")
        exit(1)


def main(git_ref, log_level, meta_files, output_file):
    setup_logging(log_level)  # Set up logging with the specified level

    repo_root = find_git_root()
    logging.debug(f"Git reference: {git_ref}")
    logging.debug(f"Git root directory: {repo_root}")

    # Find all folders in the repo that contain an 'iaciq.yaml' file.
    folders_with_metadata = find_folders_with_metadata(repo_root, meta_files)
    logging.debug(f"Folders with metadata: {folders_with_metadata}")

    # Construct the dependency graph and retrieve metadata yaml file content.
    dependency_graph, action_content = construct_dependency_graph(folders_with_metadata, meta_files)
    logging.debug(f"Dependency graph: {dependency_graph}")
    logging.debug(f"Action content: {action_content}")    
    
    # Create a reverse dependency graph for easy lookup of dependents.
    reverse_dependency_graph = get_reverse_dependency_graph(dependency_graph)
    # Before adding it to the output, convert all sets to lists
    reverse_dependency_graph_serializable = {k: list(v) for k, v in reverse_dependency_graph.items()}
    logging.debug(f"Reverse dependency graph: {reverse_dependency_graph}")

    # Get all changed folders since the given git_ref.
    folders_with_updates = get_changed_paths_since_git_ref(git_ref)
    logging.debug(f"Folders with updates: {folders_with_updates}")

    # Identify folders that need to be processed based on updates and dependencies.
    folders_to_process = find_folders_needing_processing(folders_with_updates, dependency_graph, folders_with_metadata)
    logging.debug(f"Folders to process: {folders_to_process}")

    # Calculate concurrency groups for the folders to process.
    concurrency_groups = calculate_concurrency_groups(dependency_graph, folders_to_process)
    logging.debug(f"Concurrency groups: {concurrency_groups}")

    # Prepare the final output including the dependency graph, updates, metadata, folders to process, concurrency groups, metadata yaml file content, and reverse dependency graph.
    output = {
        "iaciq": {
            "dependency_graph": dict(dependency_graph),
            "reverse_dependency_graph": reverse_dependency_graph_serializable,
            "folders_with_updates": list(folders_with_updates),
            "folders_with_metadata": folders_with_metadata,
            "folders_to_process": list(folders_to_process),
            "concurrency_groups": concurrency_groups,
            "metadata": action_content,
        }
    }

    # Write the output to 'iaciq.json'.
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=4)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Calculate folder processing order based on dependencies.")
    parser.add_argument("-r", "--git_ref", default="main", help="Git reference to compare for changes")
    parser.add_argument("-l", "--log_level", default="INFO", help="Logging level (e.g., DEBUG, INFO, WARNING, ERROR, CRITICAL)")
    parser.add_argument("-f", "--meta_files", nargs='+', default=["iaciq.yml", "iaciq.yaml"], help="Space separated list of Metadata file names to search for, defaults to 'iaciq.yml iaciq.yaml iaciq.yml iaciq.yaml'")
    parser.add_argument("-o", "--output_file", default="iaciq.json", help="Output file name, defaults to 'iaciq.json'")
    args = parser.parse_args()
    
    main(args.git_ref, args.log_level, args.meta_files, args.output_file)

