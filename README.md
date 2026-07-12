# Gorf Disassembly Project

This repository contains the disassembly and source code reconstruction for the classic arcade game *Gorf*. The primary objective is to maintain a highly accurate, clean, and readable codebase for study, preservation, and development. 

To ensure consistent formatting and layout across all development environments, all contributions and edits to the assembly source code must adhere to the project's formatting guidelines.

---

## 🛠️ Z80 Source Code Formatting Guidelines

> [!IMPORTANT]
> **A Note on Flexibility:** While consistency is key, there are exceptions to every rule. Please use your best judgment—do not shoehorn code, large data structures, or complex expressions into these specific columns if doing so compromises readability or correctness. Clarity and accuracy always take priority.

### Column Placement
To maintain strict visual alignment throughout the codebase, structure your source files using the following column boundaries:

| Code Element | Target Column | Description |
| :--- | :--- | :--- |
| **Labels** | Column 1 | All labels must begin at the absolute start of the line. |
| **Opcodes** | Column 13 | Mnemonics and assembler directives (e.g., `LD`, `DB`, `EQU`). |
| **Operands** | Column 21 | Registers, values, and memory addresses. |
| **Line Comments** | Column 41 | All trailing or standalone line comments. |

### Spacing and Tabs
* **Use Spaces Only:** Do not use hard tab characters (`\t`) anywhere in the source code. All indentation and column alignments must be achieved using spaces. 
* **Editor Configuration:** If you use the Tab key, your text editor must be configured to automatically convert tabs to spaces to ensure a consistent layout across all platforms.

##### Pattern Documentation Standards
For all Z80 assembly code patterns, user comments should follow this strict structure to ensure clarity and retain original TERSE contextual history. 

*   **Line Lengths:** Comment border lines (`;****...` and `;####...`) must be exactly 90 characters long (1 semicolon + 89 asterisks/hashes).
*   **Word Wrap:** No text inside the comment block may exceed column 88.
*   **Pattern Name:** The first line must contain the pattern name and any title/info drawn directly from the TERSE source code.
*   **Description & Context:** Include a plain-English description of what the pattern does. If the original TERSE arcade code provides meaningful logic or context, incorporate it here.
*   **Set Relationships:** If a pattern is part of a larger, interconnected set of graphics (e.g., UI indicators, player ship states), explicitly note that relationship.
*   **Omit Redundant Metadata:** Do not include byte-counting metadata (e.g., Sprite bitmap size, object total size) in individual pattern comments. This technical detail belongs in the master programming document to keep the disassembly clean.