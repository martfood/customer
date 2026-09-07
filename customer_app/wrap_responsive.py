import os
import re

directories = [
    r"c:\Users\Administrator\Desktop\MartFood\MartFood\customer_app\lib",
    r"c:\Users\Administrator\Desktop\MartFood\MartFood\shared_widgets\lib"
]

def fix_const_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content
    
    # 1. Remove const from const TextStyle(...) containing AppTypography or AppTextStyles
    # e.g., const TextStyle(..., fontSize: AppTypography.font(...))
    # Let's search for "const TextStyle(" and find its matching closing parenthesis, and if it contains "AppTypography" or "AppTextStyles", remove "const".
    # A simpler way is to find "const TextStyle" followed by some content and "AppTypography" and replace "const TextStyle" with "TextStyle"
    # Let's do regex with lookahead or search-based replacement:
    
    # We can match: const TextStyle( ... AppTypography ... )
    # Let's match: const TextStyle\(([^)]*?AppTypography[^)]*?)\)
    # Since there might be nested parentheses, let's do a block parser or regex.
    # Let's write a robust block parser for Dart files.
    
    modified = False
    
    # Let's do a simple regex find for 'const TextStyle' or 'const Text' etc.
    # Actually, we can search for any line matching const preceding a widget and containing AppTypography.
    # Let's search for: const TextStyle(
    # and replace with TextStyle(
    new_content = re.sub(r'\bconst\s+TextStyle\b', 'TextStyle', new_content)
    
    # Also if a Text or other widgets are marked const but contain AppTypography:
    # Let's parse the file and find all occurrences of "const " and check if the statement contains "AppTypography"
    # To be extremely safe, we can look at occurrences of `const Text(`, `const CustomTextField(`, `const CategoryItem(`, `const CustomButton(`, etc.
    # Let's replace: const Text( ... AppTypography ... )
    # Let's find "const Text(" and its matching parenthesis block
    
    lines = new_content.split('\n')
    for idx, line in enumerate(lines):
        if 'const' in line and ('AppTypography' in line or 'AppTextStyles' in line):
            lines[idx] = line.replace('const ', '')
            modified = True
            
    new_content = '\n'.join(lines)
    
    # Let's do multiline search for const Widget( with AppTypography inside
    # Let's find: const Text( followed by lines containing AppTypography, before the matching closing parenthesis.
    # We can match: const (Text|TextStyle|SizedBox|Padding|Container)\(([^;]*?AppTypography[^;]*?)\)
    # But let's remove 'const' from 'const Text(' if 'AppTypography' appears before the next ';' or closing block
    def remove_const_widget(match):
        content = match.group(0)
        if 'AppTypography' in content or 'AppTextStyles' in content:
            return content.replace('const ', '', 1)
        return content

    # Match const Text(...) up to the next few lines or matching braces
    new_content = re.sub(r'\bconst\s+[a-zA-Z0-9_]+\s*\([^)]*?\)', remove_const_widget, new_content)
    new_content = re.sub(r'\bconst\s+[a-zA-Z0-9_]+\s*\([^)]*?[^)]*?\)', remove_const_widget, new_content)
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed const in: {filepath}")

for d in directories:
    for root, dirs, files in os.walk(d):
        for file in files:
            if file.endswith('.dart'):
                fix_const_in_file(os.path.join(root, file))
