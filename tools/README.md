# IaC IQ Tool


## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Execution](#execution)
- [Arguments](#arguments)

## Overview

This script aids in identifying all folders that need to be processed based on being updated. Based on the updates, dependencies, and metadata information, it prepares an output file showing the order of processing considering concurrency. The information about dependencies and directory updates are taken from the Git reference that user provides.

## Installation

To run this script Python 3.x is required. The Python modules used in the script are:

- `os`
- `argparse`
- `logging`
- `yaml`
- `subprocess`
- `json`
- `collections.defaultdict`, `collections.deque`

To install the required module yaml, use the command `pip install pyyaml`.

## Execution

To run this script use the following command:

`python iaciq.py -r <git_ref> -l <log_level> -f <metadata_file_name1> <metadata_file_name2> -o <output_filename.json>`

## Arguments

- `--git_ref (-r)`: The Git reference to compare for changes. Default is `main`.
- `--log_level (-l)`: Defines the logging level, should be one of 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'. The default is 'INFO'.
- `--meta_files (-f)`: The script will search for these filenames to find the metadata. The names must be separated by space. Default values are 'iaciq.yml', 'iaciq.yaml', 'iaciq.yaml', 'iaciq.yaml' respectively.
- `--output_file (-o)`: Defines the name of the output file. The default is 'iaciq.json'.

## Outputs

Generated output file will include the following details:

- `dependency_graph`: Provides the dependencies of each folder in the processed list.
- `reverse_dependency_graph`: Shows the dependencies in reverse order.
- `folders_with_updates`: Lists out the folders which have updates since the given git reference.
- `folders_with_metadata`: Indicates all the folders where metadata files were found.
- `folders_to_process`: Lists out the folders that need to be processed considering updates and dependencies.
- `concurrency_groups`: Shows the concurrency groups calculated for processing the folders.
- `metadata`: Displays the content from metadata files found in processed directories.
