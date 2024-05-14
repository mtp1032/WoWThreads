import argparse

def lua_to_markdown(input_file, output_file):
    with open(input_file, 'r') as file:
        lines = file.readlines()
    
    in_comment_block = False
    markdown_content = []
    current_section = None
    current_text = []
    usage_block_opened = False  # To track the state of the code block for Usage

    def append_current_text():
        if current_text:
            if current_section == 'Usage:':
                markdown_content.append(f"**{current_section}**\n```lua\n{''.join(current_text).strip()}\n```")
            else:
                content = '\n'.join(current_text) if any(line.strip().startswith('-') for line in current_text) else ' '.join(current_text)
                markdown_content.append(f"**{current_section}**\n{content}\n")
            current_text.clear()

    for line in lines:
        line = line.strip()

        if line.startswith('--[[@Begin'):
            in_comment_block = True
            continue
        elif '@End]]' in line:
            append_current_text()  # Append the last text before closing the block
            in_comment_block = False
            current_section = None
            continue
        
        if in_comment_block:
            if line.startswith('--'):
                line = line.lstrip('-').lstrip()

            if any(line.startswith(keyword) for keyword in ['Title:', 'Signature:', 'Description:', 'Parameters:', 'Returns:', 'Usage:']):
                if current_section == 'Usage:' and not usage_block_opened:
                    markdown_content.append("```")  # Close the previous 'Usage' code block
                    usage_block_opened = False
                append_current_text()
                current_section = line.split(':')[0] + ':'
                if 'Usage:' in current_section:
                    usage_block_opened = True  # Mark that we're starting a 'Usage' block
                continue

            if line.startswith('-'):
                current_text.append(line)  # Treat as a separate list item
            else:
                current_text.append(line)  # Continue appending narrative text to the current section

    if current_section == 'Usage:' and usage_block_opened:
        markdown_content.append("```")  # Ensure the 'Usage' code block is closed

    with open(output_file, 'w') as md_file:
        md_file.write('\n'.join(markdown_content))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert Lua comment blocks to Markdown format.')
    parser.add_argument('input_file', type=str, help='Lua source file to convert.')
    args = parser.parse_args()

    output_file = args.input_file.rsplit('.', 1)[0] + '.md'
    lua_to_markdown(args.input_file, output_file)
