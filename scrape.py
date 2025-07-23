import os

# --- Configuration ---

# Add or remove file extensions to control which file types are included.
# The dot (.) is important.
FILE_TYPE_INCLUSION_LIST = ['.js', '.json']

# Add complete file names that you want to explicitly exclude from scraping.
FILE_NAME_EXCLUSION_LIST = ['phaser.js', 'package-lock.json', 'vendor.js']

# Add directory names to exclude from the search entirely.
# This is useful for directories like 'node_modules', '.git', 'dist', etc.
DIRECTORY_NAME_EXCLUSION_LIST = ['node_modules', '.git', 'dist', 'build']

# Define the name of the output file.
OUTPUT_FILENAME = 'scraped_output.txt'

def build_repository_map(current_path, prefix="", is_last=False):
    """
    Recursively builds a tree visualization of the directory and collects files to scrape.

    Args:
        current_path (str): The path to the directory to start building from.
        prefix (str): The prefix for the current line (contains indentation and connectors).
        is_last (bool): Flag to determine if the current item is the last in its parent list.

    Returns:
        tuple: A tuple containing:
            - list: A list of strings, where each string is a line in the tree.
            - list: A list of full paths to the files that should be scraped.
    """
    # Exclude the script file itself
    script_name = os.path.basename(__file__)
    
    try:
        entries = [e for e in os.listdir(current_path) if e != script_name]
    except OSError:
        return [], []

    dirs = sorted([d for d in entries if os.path.isdir(os.path.join(current_path, d)) and d not in DIRECTORY_NAME_EXCLUSION_LIST])
    files = sorted([f for f in entries if os.path.isfile(os.path.join(current_path, f))])

    all_entries = dirs + files
    tree_lines = []
    files_to_scrape = []

    for i, name in enumerate(all_entries):
        is_current_last = (i == len(all_entries) - 1)
        connector = "└── " if is_current_last else "├── "
        line_prefix = prefix + connector
        
        full_path = os.path.join(current_path, name)
        
        if name in dirs:
            tree_lines.append(line_prefix + name)
            child_prefix = prefix + ("    " if is_current_last else "│   ")
            child_lines, child_files_to_scrape = build_repository_map(full_path, child_prefix)
            tree_lines.extend(child_lines)
            files_to_scrape.extend(child_files_to_scrape)
        else: # It's a file
            _, file_extension = os.path.splitext(name)
            is_excluded_by_name = name in FILE_NAME_EXCLUSION_LIST
            is_included_by_type = file_extension in FILE_TYPE_INCLUSION_LIST
            
            file_display_name = name
            if not is_excluded_by_name and is_included_by_type:
                file_display_name += " (*)"
                files_to_scrape.append(full_path)
            
            tree_lines.append(line_prefix + file_display_name)
            
    return tree_lines, files_to_scrape


def run_scrape():
    """
    Main function to orchestrate the scraping process.
    """
    root_directory = os.getcwd()
    print(f"Starting scrape in directory: {root_directory}...")

    # 1. Generate the tree visualization and get the list of files to process
    print("Step 1: Analyzing directory structure and identifying files...")
    
    # Start the recursive build
    initial_tree_lines, files_to_process = build_repository_map(root_directory)
    # Prepend the root directory name
    tree_visualization = f"{os.path.basename(root_directory)} (root)\n" + "\n".join(initial_tree_lines)
    
    print(f"Identified {len(files_to_process)} files to scrape.")

    # 2. Write everything to the output file
    print(f"Step 2: Writing to output file: {OUTPUT_FILENAME}")
    try:
        with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as output_file:
            # Write the repository map to the file
            output_file.write("--- REPOSITORY MAP ---\n")
            output_file.write(tree_visualization)
            output_file.write("\n\n\n--- FILE CONTENTS ---\n\n")

            # Process each file from the generated list
            for file_path in files_to_process:
                filename = os.path.basename(file_path)
                print(f"    -> Processing: {file_path}")
                
                try:
                    # Open and read the content of the target file
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as current_file:
                        # Write file header and contents
                        output_file.write(f"[{filename}]\n")
                        contents = current_file.read()
                        output_file.write(contents)
                        output_file.write('\n\n')
                except Exception as e:
                    print(f"!!! Could not read file {file_path}: {e}")
                    
    except IOError as e:
        print(f"!!! An error occurred while writing to the output file: {e}")
        return

    print("\nScraping complete.")
    print(f"Total files written: {len(files_to_process)}")
    print(f"Output saved to: {OUTPUT_FILENAME}")

if __name__ == '__main__':
    run_scrape()