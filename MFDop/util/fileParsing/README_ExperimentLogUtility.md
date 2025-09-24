# Experiment Log Utility

This utility provides an automated way to read experiment configurations from a standardized Excel log file, eliminating the need to manually hardcode experiment parameters in MATLAB processing scripts. Features robust parsing to handle various user input formats and automatic x-coordinate extraction for enhanced file naming.

## Overview

The `readExperimentLog.m` function reads experiment data from an Excel spreadsheet and automatically generates the required data structures (`rawfn`, `heads`, `fout`) for MFDop L1 processing. The function includes:

- **Robust parsing** of beam configurations (handles mixed case, underscores, spacing variations)
- **Automatic x-coordinate extraction** from coordinate data
- **Enhanced filename generation** with x-coordinates included
- **Start time extraction** in MATLAB datenum format for future use
- **Error handling** for malformed or missing data

## Files

- `util/readExperimentLog.m` - Main utility function
- `test_readExperimentLog.m` - Test script to validate the utility
- `test_robust_parsing.m` - Comprehensive test suite for robust parsing features
- `MFDop_L1proc_20250918_with_utility.m` - Example processing script using the utility
- `example_workflow.m` - Complete workflow demonstration
- `STONE2025_09182025.xlsx` - Example experiment log spreadsheet

## Usage

### Basic Usage

```matlab
% Define parameters
xlsxFile = 'STONE2025_09182025.xlsx';
basedir = '/path/to/raw/data';
outdir = 'path/to/output';
dateStr = '20250918';

% Read experiment log
[rawfn, heads, fout] = readExperimentLog(xlsxFile, basedir, outdir, dateStr);
```

### Integration with Processing Scripts

Replace the manual "USER INPUT" block in your processing scripts:

**Before (manual entry):**
```matlab
% Manual entry of each trial
fout{end+1} = [outdir '/DD_20250918_case1p3Trial01'];
rawfn{end+1} = fileList_ls([basedir '/DragonData.*.00000*.mat']);
heads{end+1} = {'Aux1','Aux2'};
% ... repeat for each trial
```

**After (using utility):**
```matlab
% Automated reading from Excel log
[rawfn, heads, fout, startTimeApprox_cdt] = readExperimentLog(xlsxFile, basedir, outdir, dateStr);
```

## Excel File Format

The utility expects a specific Excel file format with the following columns:

| Column | Header | Example | Description |
|--------|--------|---------|-------------|
| 1 | Case&Trial | 1.3_03 | Case and trial identifier |
| 3 | Time Start (CDT) | 10:38:00 or 0.44375 | Start time (string or Excel numeric) |
| 4 | MFDop Head X-Coord | 127.5 | X-coordinate for Main head |
| 5 | Aux 1 Coords (x, y, z) | (137, 123.5, 26) | Aux1 head coordinates |
| 6 | Aux 2 Coords (x, y, z) | (137, 73.5, 12.5) | Aux2 head coordinates |
| 7 | MFDop Transmitting Beams | Aux 1, Aux 2 | Active beam configuration |
| 12 | MFDop File | 2.0 | MFDop file sequence number |

### Supported Beam Configurations (Tokenized Parsing)

The utility uses tokenized parsing to handle all possible head combinations:

**Single Head Configurations:**
- `"Main Head"`, `"MAIN"`, `"main head"` → `{'Main'}`
- `"Aux 1"`, `"aux1"`, `"AUX_1"`, `"aux_1"` → `{'Aux1'}`
- `"Aux 2"`, `"aux2"`, `"AUX_2"`, `"aux_2"` → `{'Aux2'}`

**Dual Head Combinations:**
- `"Aux 1, Aux 2"`, `"aux1, aux2"`, `"AUX_1, AUX_2"` → `{'Aux1', 'Aux2'}`
- `"Main Head, Aux 1"`, `"main, aux1"` → `{'Main', 'Aux1'}`
- `"Main Head, Aux 2"`, `"main, aux2"` → `{'Main', 'Aux2'}`

**Triple Head Combinations:**
- `"Main Head, Aux 1, Aux 2"`, `"main, aux1, aux2"` → `{'Main', 'Aux1', 'Aux2'}`
- `"Aux2, Aux1, Main"` → `{'Main', 'Aux1', 'Aux2'}` (auto-sorted)

**Parsing Features:**
- Tokenizes on commas to handle all combinations
- Switch-based standardization for consistent naming
- Automatic duplicate removal and head ordering
- Case-insensitive with underscore/space normalization

### File Number Mapping

The MFDop file number is converted to a 5-digit zero-padded pattern:
- File number `2` → Pattern `00002`
- File number `15` → Pattern `00015`

This pattern is used to find DragonData files: `DragonData.*.00002*.mat`

### X-Coordinate Extraction and Filename Integration

X-coordinates are automatically extracted and included in output filenames:

**For Main Head trials:**
- Uses the value from "MFDop Head X-Coord" column (single numeric value)

**For Auxiliary Head trials:**
- Extracts x-coordinate from coordinate triplets like `"(137, 123.5, 26)"` 
- Handles various formats: `"(137, 123.5, 26)"`, `"( 140.5 , 100 , 20)"`, `"(142,90,15)"`
- For dual aux heads, uses Aux1 coordinates (should match Aux2)

**Enhanced Output Filenames:**
- Original: `DD_20250918_case1p3Trial03_Aux1_L1.mat`
- New: `DD_20250918_case1p3Trial03_x137_Aux1_L1.mat`

## Function Details

### `readExperimentLog(xlsxFile, basedir, outdir, dateStr)`

**Inputs:**
- `xlsxFile` - Path to Excel log file
- `basedir` - Directory containing raw DragonData files
- `outdir` - Output directory for processed files
- `dateStr` - Date string for output filenames (e.g., '20250918')

**Outputs:**
- `rawfn` - Cell array of file lists for each trial
- `heads` - Cell array of active heads for each trial  
- `fout` - Cell array of output filenames for each trial
- `startTimeApprox_cdt` - Array of start times in MATLAB datenum format (CDT)

**Example Output:**
```matlab
rawfn{1} = {'/path/to/DragonData.20250918.00002.001.mat', ...}
heads{1} = {'Aux1', 'Aux2'}
fout{1} = 'data/20250918/MFDop_L1/DD_20250918_case1p3Trial03_x137'
startTimeApprox_cdt(1) = 737303.4431 % MATLAB datenum for '2025-09-18 10:38:00'
```

**Final Output Files:**
```
DD_20250918_case1p3Trial03_x137_Aux1_L1.mat
DD_20250918_case1p3Trial03_x137_Aux1_L1.png  
DD_20250918_case1p3Trial03_x137_Aux1_L1.fig
DD_20250918_case1p3Trial03_x137_Aux2_L1.mat
DD_20250918_case1p3Trial03_x137_Aux2_L1.png
DD_20250918_case1p3Trial03_x137_Aux2_L1.fig
```

## Testing

### Basic Validation Test
Run the main test script to validate the utility:

```matlab
run('test_readExperimentLog.m')
```

This will:
- Read the Excel file and display results
- Compare against expected patterns
- Show summary statistics
- Validate file numbering and head configurations
- Check x-coordinate extraction and filename formatting

### Comprehensive Robust Parsing Test
Run the detailed parsing test suite:

```matlab
run('test_robust_parsing.m')
```

This comprehensive test validates:
- Beam string normalization with various input formats
- Head configuration detection across different cases and formats
- X-coordinate extraction from various coordinate string formats
- Complete integration testing with simulated Excel data

## Benefits

1. **Eliminates manual transcription errors** - No more copying data from spreadsheets by hand
2. **Maintains single source of truth** - Excel log serves as the authoritative record
3. **Reduces code maintenance** - Changes to experiment parameters only need to be made in one place
4. **Improves reproducibility** - Processing parameters are automatically documented in the log file
5. **Speeds up processing setup** - No manual editing required for new experiment runs
6. **Robust input handling** - Tolerates variations in user data entry (case, spacing, formatting)
7. **Enhanced file organization** - X-coordinates in filenames improve data management
8. **Start time tracking** - Automatic extraction of experiment start times for temporal analysis
9. **Automatic error detection** - Warns about malformed or missing data

## Migration from Manual Entry

To convert existing processing scripts:

1. Replace the manual USER INPUT block with the utility function call
2. Ensure your Excel log file follows the expected format
3. Test with `test_readExperimentLog.m` before running full processing
4. Keep the original script as backup during initial testing

## Error Handling

The utility includes error checking for:
- Missing or empty critical data fields
- Unknown beam configurations (after normalization attempts)
- Invalid file numbers
- Missing Excel file or unreadable format
- Malformed coordinate strings
- Missing x-coordinate data
- Malformed time strings or invalid time formats

Warnings are displayed for any skipped trials, and a summary shows the total number of trials processed. The robust parsing attempts to handle input variations before flagging errors.

## Notes

- The utility automatically filters out rows with missing data
- File patterns use the `fileList_ls` function which requires the `util/generic` directory in the MATLAB path
- Output filenames follow enhanced convention: `DD_YYYYMMDD_caseXpXTrialXX_xNNN`
- X-coordinates are rounded to nearest integer for filename generation
- Main head trials can be filtered out if beam2uvw processing is not ready
- Robust parsing handles most common input variations automatically
- For coordinate parsing, the function extracts the first number found if standard formats fail
- Start times are converted to MATLAB datenum format combining the experiment date with parsed times
- Both Excel numeric time formats (decimal fractions) and string formats ("HH:MM:SS") are supported
- Uses modernized `fileList_ls` function with improved performance and error handling
- Tokenized beam parsing handles any combination of heads (Main, Aux1, Aux2)

## Input Format Flexibility

The utility is designed to handle real-world spreadsheet variations:

**Beam Configuration Examples:**
```
"Aux 1, Aux 2"          →  Aux1, Aux2
"Main Head, Aux 1"      →  Main, Aux1  
"aux1, main, aux2"      →  Main, Aux1, Aux2
"Aux2, Aux1, Main"      →  Main, Aux1, Aux2  (auto-sorted)
"Main Head"             →  Main
"aux1"                  →  Aux1
```

**Coordinate Format Examples:**
```
"(137, 123.5, 26)"      →  x = 137
"( 140.5 , 100 , 20)"   →  x = 140.5
"(142,90,15)"           →  x = 142
"137, 123.5, 26"        →  x = 137  (fallback)
```

**Start Time Format Examples:**
```
"10:38:00"              →  datenum for 2025-09-18 10:38:00 CDT
"14:13:00"              →  datenum for 2025-09-18 14:13:00 CDT  
0.44375 (Excel format)  →  datenum for 2025-09-18 10:39:00 CDT
```

## File Listing Improvements

The utility now uses an improved `fileList_ls` function that:

**Modern MATLAB Implementation:**
- Uses `dir()` function instead of unix commands for better performance
- No dependency on external tools (more reliable across platforms)
- Better memory management for large file lists
- Improved error handling and warning messages

**Enhanced Error Handling:**
- Warning mode (`errtype=0`): Returns empty cell array with warning if no files match
- Error mode (`errtype=1`): Throws descriptive error if no files match
- Input validation for patterns and error types
- Graceful handling of filesystem errors

**Performance Benefits:**
- Faster file enumeration, especially for large directories
- No process spawning overhead
- Consistent behavior across different operating systems
- Better handling of special characters in filenames

**Backward Compatibility:**
- Same function signature and behavior
- Returns single string for one file, cell array for multiple files
- Maintains existing error handling modes

## Tokenized Beam Parsing

The utility now uses a sophisticated tokenization approach for beam configurations:

**Parsing Process:**
1. **Tokenization**: Split input string on commas: `"Main, Aux1, Aux2"` → `["Main", "Aux1", "Aux2"]`
2. **Normalization**: Each token is cleaned (case, spaces, underscores)
3. **Standardization**: Switch statement maps variants to standard names
4. **Deduplication**: Remove duplicate heads from different naming variants
5. **Ordering**: Sort heads in standard order (Main, Aux1, Aux2)

**Benefits:**
- Handles any valid combination of heads
- Robust to user input variations
- Extensible for future head types
- Clear error messages for unknown configurations
- Consistent output format regardless of input order