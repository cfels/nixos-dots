# Quickshell Media Caching System

This directory contains scripts for managing media (artwork and lyrics) caching in the Quickshell panel.

## Files

### artwork-fetch.sh
The main script for fetching and caching artwork. It:
- Handles various sources of artwork including direct URLs, local files, YouTube thumbnails, and iTunes search
- Uses ImageMagick to validate images
- Implements a caching system with size limits
- Prevents duplicate artwork downloads

### media-cache.py
Python script that manages the cache directory:
- Maintains a 150MB cache limit across lyrics and artwork
- Handles cache entry validation and cleanup
- Implements proper pruning of old entries when cache is full
- Uses a protected file approach to avoid deleting currently used files

### media-match.jq
A jq module for matching tracks based on title, artist, and album information with fuzzy matching.

## Cache Behavior

The system maintains two types of cached data:
1. Lyrics (in `lyrics/v1/`)
2. Artwork (in `art/`)

Cache entries are automatically pruned when:
- The total cache size exceeds 150MB
- Individual entries exceed 2MB in size
- Cache entries expire after 15 minutes of inactivity

## Troubleshooting

If you're experiencing caching issues:
1. Check that ImageMagick (`magick`) and jq are installed
2. Verify the cache directory has proper permissions
3. Monitor system resources as large image processing can be memory-intensive
4. Ensure there's sufficient disk space available for temporary files during downloads

## Usage

The scripts are typically called by Quickshell panel components when media information changes.