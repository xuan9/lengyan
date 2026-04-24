# Lengyan Sutra Data Structure Documentation

This document describes the JSON structure used for organizing the Lengyan Sutra (楞严经) content in the project.

## Overview

The Lengyan Sutra data is organized across four JSON files that work together to provide content, indexing, and hierarchical structure information.

## File Structures

### 1. `lengyanjing-index.json`
- **Type**: Array of objects
- **Structure**:
  ```json
  [
    {
      "id": "string",          // Unique identifier for the section
      "name": "string",        // Display name of the section
      "path": "string",        // Hierarchical path identifier (e.g., "/A1/B1/C1")
      "title": "string"        // Optional title/description
    }
  ]
  ```
- **Purpose**: Provides a flat index of all content sections with metadata

### 2. `lengyanjing-index-tree.json`
- **Type**: Hierarchical tree structure
- **Structure**:
  ```json
  {
    "id": "string",            // Unique identifier for the root section
    "name": "string",          // Display name of the root section
    "path": "string",          // Hierarchical path identifier
    "children": [              // Array of child sections
      {
        "id": "string",
        "name": "string",
        "path": "string",
        "children": [          // Recursive children array structure
          // ...
        ]
      }
    ]
  }
  ```
- **Purpose**: Represents the hierarchical organization of the sutra with nested relationships

### 3. `lengyanjing-content.json`
- **Type**: Map/object with path keys
- **Structure**:
  ```json
  {
    "/A1/B1/C1": [             // Path key corresponds to sections in index files
      {
        "type": "string",      // Content type (e.g., "sutra", "commentary")
        "content": "string"    // The actual text content
      }
    ]
  }
  ```
- **Purpose**: Contains the actual sutra text content organized by path identifiers

### 4. `enhanced-lengyanjing-content.json`
- **Type**: Map/object with path keys
- **Structure**:
  ```json
  {
    "/A1/B1/C1": {
      "chapter": "number",     // Chapter number
      "content": [             // Array of content blocks
        {
          "type": "string",    // Content type (e.g., "sutra", "commentary")
          "content": "string"  // The actual text content
        }
      ]
    }
  }
  ```
- **Purpose**: Enhanced version of content with additional metadata like chapter numbers

## Relationship Between Files

All files use the same path identifiers (like `/A1/B1/C1`) to maintain consistency:
- `lengyanjing-index.json` provides flat access to section names and paths
- `lengyanjing-index-tree.json` represents hierarchy through nested structures
- `lengyanjing-content.json` contains text content indexed by paths
- `enhanced-lengyanjing-content.json` contains enriched text content with chapter information

## Path Identifier Convention

The path identifiers follow a hierarchical pattern:
- `A1` - Major sections (e.g., 序分, 正宗分)
- `B1`, `B2` - Subsections within major sections
- `C1`, `C2`, etc. - Further subdivisions
- This creates unique addresses like `/A1/B1/C1/D1/E1` for specific content blocks