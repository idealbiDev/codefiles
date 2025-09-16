import pandas as pd
import ollama
import logging
import re
import os
import hashlib
import pickle
from typing import Dict, Any, List

# --- Configuration ---
# Configure logging to see the script's progress and any potential issues.
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Directory for caching LLM responses to avoid redundant calls.
CACHE_DIR = 'ollama_cache'
if not os.path.exists(CACHE_DIR):
    os.makedirs(CACHE_DIR)

# --- Helper Functions ---

def _get_cache_key(prompt: str) -> str:
    """Generate a unique MD5 hash for a given prompt to use as a cache key."""
    return hashlib.md5(prompt.encode()).hexdigest()

def _load_from_cache(cache_key: str) -> Any:
    """Load a response from the cache if it exists."""
    cache_file = os.path.join(CACHE_DIR, f'{cache_key}.pkl')
    if os.path.exists(cache_file):
        with open(cache_file, 'rb') as f:
            return pickle.load(f)
    return None

def _save_to_cache(cache_key: str, response: Any):
    """Save a response to the cache."""
    cache_file = os.path.join(CACHE_DIR, f'{cache_key}.pkl')
    with open(cache_file, 'wb') as f:
        pickle.dump(response, f)

def _parse_markdown_description(description: str) -> Dict[str, str]:
    """
    Parse the markdown description from the LLM into a structured dictionary.
    This version is more robust to variations in the LLM's output.
    """
    patterns = {
        'business_purpose': r'\*\*Business Purpose\*\*:\s*(.*?)(?=\n-|\n\n|$)',
        'data_quality_rules': r'\*\*Data Quality Rules\*\*:\s*(.*?)(?=\n-|\n\n|$)',
        'example_usage': r'\*\*Example Usage\*\*:\s*(.*?)(?=\n-|\n\n|$)',
        # Handles both "Issues" and "Known Issues/Limitations" for flexibility
        'issues': r'\*\*(?:Known Issues/Limitations|Issues)\*\*:\s*(.*?)(?=\n-|\n\n|$)'
    }
    result = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, description, re.DOTALL | re.IGNORECASE)
        result[key] = match.group(1).strip() if match else 'N/A'
    return result

def _generate_description_with_ollama(
    table_name: str, 
    column_info: Dict[str, Any], 
    sample_values: List[Any],
    model: str
) -> str:
    """
    Generate a column description using a local Ollama model.
    """
    prompt = f"""
    As a data governance expert, provide a concise description for the following database column:
    
    Table: {table_name}
    Column: {column_info['column_name']}
    Data Type: {column_info['data_type']}
    Is Nullable: {column_info['is_nullable']}
    
    Here are a few sample values from the column: {sample_values}
    
    Please provide the following information in markdown format:
    - **Business Purpose**: Briefly describe the column's role in business processes (1 clear sentence).
    - **Data Quality Rules**: List 1-2 critical rules to ensure data integrity (e.g., format, range, uniqueness).
    - **Example Usage**: Provide one practical example of how this column is used in analysis or operations.
    - **Known Issues/Limitations**: Identify 1-2 potential data quality issues or limitations.
    
    Keep the total response under 200 words.
    """
    
    cache_key = _get_cache_key(prompt)
    cached_response = _load_from_cache(cache_key)
    if cached_response:
        logging.info(f"CACHE HIT: Retrieved description for {column_info['column_name']} in {table_name}")
        return cached_response

    logging.info(f"CACHE MISS: Generating description for {column_info['column_name']} in {table_name} using '{model}'...")
    try:
        # Initialize the Ollama client
        client = ollama.Client()
        response = client.chat(
            model=model,
            messages=[{'role': 'user', 'content': prompt}],
            options={'temperature': 0.2}
        )
        description = response['message']['content'].strip()
        _save_to_cache(cache_key, description)
        logging.info(f"SUCCESS: Generated and cached description for {column_info['column_name']}")
        return description
    
    except Exception as e:
        logging.error(f"Error generating description for {column_info['column_name']}: {e}")
        fallback = (
            f"- **Business Purpose**: Could not determine purpose for {column_info['column_name']}.\n"
            f"- **Data Quality Rules**: Must conform to data type {column_info['data_type']}.\n"
            f"- **Example Usage**: Used for general analysis within the {table_name} table.\n"
            f"- **Known Issues/Limitations**: LLM description generation failed: {e}"
        )
        return fallback

# --- Main Function ---

def generate_descriptions_from_csv(csv_file_path: str, model: str = 'llama3') -> Dict[str, List[Dict[str, Any]]]:
    """
    Reads a CSV file, analyzes its columns, and generates structured descriptions using a local Ollama model.

    Args:
        csv_file_path (str): The full path to the input CSV file.
        model (str, optional): The name of the Ollama model to use. Defaults to 'llama3'.

    Returns:
        Dict[str, List[Dict[str, Any]]]: A dictionary where the key is the table name (derived from the
        CSV filename) and the value is a list of dictionaries, each describing a column.
    """
    if not os.path.exists(csv_file_path):
        logging.error(f"File not found: {csv_file_path}")
        return {}

    try:
        df = pd.read_csv(csv_file_path)
        # Derive table name from the filename (e.g., 'sales_data.csv' -> 'sales_data')
        table_name = os.path.splitext(os.path.basename(csv_file_path))[0]
        logging.info(f"Processing table '{table_name}' with {len(df.columns)} columns.")

        all_column_info = []
        for column_name in df.columns:
            # 1. Gather metadata directly from the DataFrame
            column_info_metadata = {
                'column_name': column_name,
                'data_type': str(df[column_name].dtype),
                'is_nullable': 'YES' if df[column_name].isnull().any() else 'NO'
            }
            sample_values = df[column_name].dropna().unique().tolist()[:5]

            # 2. Generate the description using the LLM
            description_md = _generate_description_with_ollama(table_name, column_info_metadata, sample_values, model)

            # 3. Parse the markdown into a structured dictionary
            parsed_desc = _parse_markdown_description(description_md)
            
            # 4. Format the final output structure
            final_column_structure = {
                'column_name': column_name,
                'column_desc': [parsed_desc] # Nested as per your original code's implied structure
            }
            all_column_info.append(final_column_structure)
        
        return {table_name: all_column_info}

    except Exception as e:
        logging.error(f"An error occurred while processing {csv_file_path}: {e}")
        return {}

# --- Example Usage ---
if __name__ == '__main__':
    # Create a dummy CSV file for demonstration purposes
    dummy_data = {
        'TransactionID': [101, 102, 103, 104, 105],
        'ProductSKU': ['ABC-123', 'XYZ-789', 'ABC-123', 'DEF-456', 'XYZ-789'],
        'SaleAmount': [99.99, 150.00, 49.95, 25.50, 150.00],
        'TransactionDate': ['2025-09-15', '2025-09-15', '2025-09-16', '2025-09-16', None],
        'StoreID': ['STORE-A', 'STORE-B', 'STORE-A', 'STORE-C', 'STORE-B']
    }
    dummy_df = pd.DataFrame(dummy_data)
    file_path = 'sample_sales_data.csv'
    dummy_df.to_csv(file_path, index=False)
    
    print(f"Created dummy data file: '{file_path}'")
    
    # Generate the descriptions
    # Ensure you have Ollama running with the 'llama3' model pulled (`ollama pull llama3`)
    generated_descriptions = generate_descriptions_from_csv(file_path, model='llama3')
    
    # Pretty-print the result
    import json
    print("\n--- Generated Column Descriptions ---")
    print(json.dumps(generated_descriptions, indent=2))