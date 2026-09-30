#!/usr/bin/env node

/**
 * GLB Compression Script - Uses locally installed gltf-transform packages
 * This script compresses all .glb files in a directory with Draco compression
 *
 * SETUP: Run setup_compression.bat first to install dependencies
 * Usage: node compress_glb_local.js <path-to-assets-folder>
 */

const fs = require('fs');
const path = require('path');

// Try to require gltf-transform - should be in local node_modules
let gltfTransform;
let NodeIO;
let dracoExtension;

try {
    gltfTransform = require('@gltf-transform/core');
    NodeIO = gltfTransform.NodeIO;
    dracoExtension = require('@gltf-transform/extensions').DRACO_COMPRESSION;
} catch (e) {
    console.error('\n' + '='.repeat(70));
    console.error('ERROR: gltf-transform packages not found!');
    console.error('='.repeat(70));
    console.error('\nPlease run setup_compression.bat first to install dependencies.');
    console.error('\nThe error was: ' + e.message);
    console.error('\n' + '='.repeat(70) + '\n');
    process.exit(1);
}

const assetsPath = process.argv[2];

if (!assetsPath) {
    console.error('Usage: node compress_glb_local.js <path-to-assets-folder>');
    process.exit(1);
}

if (!fs.existsSync(assetsPath)) {
    console.error(`Error: Path does not exist: ${assetsPath}`);
    process.exit(1);
}

// Find all .glb files recursively
function findGlbFiles(dir) {
    let files = [];
    const items = fs.readdirSync(dir, { withFileTypes: true });

    for (const item of items) {
        const fullPath = path.join(dir, item.name);
        if (item.isDirectory()) {
            files = files.concat(findGlbFiles(fullPath));
        } else if (item.name.endsWith('.glb')) {
            files.push(fullPath);
        }
    }
    return files;
}

const glbFiles = findGlbFiles(assetsPath);

if (glbFiles.length === 0) {
    console.error(`No .glb files found in ${assetsPath}`);
    process.exit(1);
}

console.log(`Found ${glbFiles.length} GLB files to compress\n`);

let totalBefore = 0;
let totalAfter = 0;
let successCount = 0;

(async () => {
    const io = new NodeIO();

    for (let i = 0; i < glbFiles.length; i++) {
        const filePath = glbFiles[i];
        const stats = fs.statSync(filePath);
        const sizeBefore = stats.size;
        totalBefore += sizeBefore;

        const relativePath = path.relative(assetsPath, filePath);
        const sizeBeforeMB = (sizeBefore / 1024 / 1024).toFixed(2);

        process.stdout.write(`Compressing [${i + 1}/${glbFiles.length}] ${relativePath} (${sizeBeforeMB}MB)... `);

        try {
            // Read GLB file
            const doc = await io.read(filePath);

            // Create and apply Draco compression extension
            doc.createExtension(dracoExtension);

            // Write back to file
            await io.write(filePath, doc);

            // Check result
            const statsAfter = fs.statSync(filePath);
            const sizeAfter = statsAfter.size;

            if (sizeAfter > 0) {
                totalAfter += sizeAfter;
                successCount++;

                const reduction = ((1 - sizeAfter / sizeBefore) * 100).toFixed(1);
                const sizeAfterMB = (sizeAfter / 1024 / 1024).toFixed(2);

                console.log(`✓ ${sizeAfterMB}MB (${reduction}% smaller)`);
            } else {
                console.log(`✗ Failed: File size is 0 bytes after compression`);
            }
        } catch (error) {
            console.log(`✗ Failed: ${error.message}`);
        }
    }

    const totalReduction = totalBefore > 0 ? ((1 - totalAfter / totalBefore) * 100).toFixed(1) : 0;
    const savedMB = ((totalBefore - totalAfter) / 1024 / 1024).toFixed(1);

    console.log(`\n${'='.repeat(70)}`);
    console.log(`Successfully compressed: ${successCount}/${glbFiles.length} files`);
    console.log(`Total before: ${(totalBefore / 1024 / 1024).toFixed(1)}MB`);
    console.log(`Total after:  ${(totalAfter / 1024 / 1024).toFixed(1)}MB`);
    console.log(`Saved:        ${savedMB}MB (${totalReduction}% reduction)`);
    console.log(`${'='.repeat(70)}\n`);

    if (successCount === glbFiles.length) {
        console.log('✓ All files compressed successfully!');
    } else {
        console.log(`⚠ ${glbFiles.length - successCount} files failed. Check console output above.`);
    }

    process.exit(successCount === glbFiles.length ? 0 : 1);
})().catch(err => {
    console.error('Fatal error:', err.message);
    process.exit(1);
});
