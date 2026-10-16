/**
 * Penrose Bio-Lab — 20 coordinated laboratory colour themes.
 *
 * Loaded by index.html before the main module; exposed as window.BIO_LAB_THEMES
 * (browser) and module.exports (node, for scripts/themes_test.mjs).
 *
 * Slots: floor, wall, dado, rail, ceil, slab, top, carcass, door, cab,
 * plinth, dark, frame, shelf, board, baseClad, fill.
 * `fill` (specimen-jar fills): null = keep the original mixed colours.
 * Stools are shiny stainless steel and are never themed.
 */
(function (root) {
  'use strict';

  var THEMES = [
    {
      name: 'Classic Institutional',
      floor: 0xffffff, wall: 0xd9d7cc, dado: 0x8fae9a, rail: 0x648571, ceil: 0xdedcd6,
      slab: 0x6f7975, top: 0x0b0d0f, carcass: 0xf2efe6, door: 0xd8ab70, cab: 0xe3dfd1,
      plinth: 0x3d474b, dark: 0x1b2022, frame: 0xf7f7f2, shelf: 0xc19760,
      board: 0xffffff, baseClad: 0x4a2f1d, fill: null
    },
    {
      name: 'Modern Clinical White',
      floor: 0xd2d7da, wall: 0xf4f6f5, dado: 0x9fb4bc, rail: 0x6d8891, ceil: 0xf7f9fa,
      slab: 0x8a959b, top: 0x232a2e, carcass: 0xffffff, door: 0xb8c4c9, cab: 0xe8eef0,
      plinth: 0x39434a, dark: 0x14181b, frame: 0xffffff, shelf: 0xc5cdd1,
      board: 0xf7fbfc, baseClad: 0x3d4a50, fill: null
    },
    {
      name: 'Nordic Light',
      floor: 0xd8c8ac, wall: 0xf2efe8, dado: 0xc4b8a2, rail: 0x8e8271, ceil: 0xf6f4ef,
      slab: 0xa0937d, top: 0x33302b, carcass: 0xf6f2e9, door: 0xc4a06a, cab: 0xece6da,
      plinth: 0x4a433a, dark: 0x1e1c18, frame: 0xfaf8f3, shelf: 0xd2b98c,
      board: 0xfbf9f4, baseClad: 0x5c4a32, fill: null
    },
    {
      name: 'Ocean Science',
      floor: 0x9db4c4, wall: 0xe3edf3, dado: 0x4e7f9e, rail: 0x2f5a75, ceil: 0xecf3f7,
      slab: 0x6f8794, top: 0x14212b, carcass: 0xdce8ee, door: 0x7fa7c6, cab: 0xc6d7e0,
      plinth: 0x26343e, dark: 0x0e161c, frame: 0xf2f7fa, shelf: 0x9aafc0,
      board: 0xeef6fa, baseClad: 0x1e3c4e, fill: null
    },
    {
      name: 'Bio Green',
      floor: 0xa8b89a, wall: 0xe6ecdd, dado: 0x5f8a52, rail: 0x3d6135, ceil: 0xeef2e6,
      slab: 0x7d8f72, top: 0x1c241c, carcass: 0xe4ebd8, door: 0x8faf6e, cab: 0xcfd9c0,
      plinth: 0x2c3a2a, dark: 0x121812, frame: 0xf3f6ee, shelf: 0xa8c08e,
      board: 0xf0f5e8, baseClad: 0x2e4426, fill: null
    },
    {
      name: 'Teal Research',
      floor: 0x9cbdb8, wall: 0xe8f2f0, dado: 0x2f7d74, rail: 0x1d5850, ceil: 0xf0f7f5,
      slab: 0x6a918c, top: 0x102422, carcass: 0xdcebe8, door: 0x5fa8a0, cab: 0xc2dbd7,
      plinth: 0x1e3230, dark: 0x0c1816, frame: 0xf4f9f8, shelf: 0x8fb5b0,
      board: 0xeef7f5, baseClad: 0x16403a, fill: null
    },
    {
      name: 'Charcoal & Silver',
      floor: 0x8f9599, wall: 0x8e9397, dado: 0x5a6064, rail: 0x3c4145, ceil: 0xb4b9bc,
      slab: 0x6c7175, top: 0x141618, carcass: 0xc9cccf, door: 0x9aa1a6, cab: 0xb7bbbe,
      plinth: 0x2a2e31, dark: 0x0e1012, frame: 0xd7dadd, shelf: 0xa7abae,
      board: 0xdfe2e4, baseClad: 0x22262a, fill: null
    },
    {
      name: 'Warm Timber',
      floor: 0xc9a06a, wall: 0xf0e6d4, dado: 0xc07f4a, rail: 0x8a5730, ceil: 0xf5eddd,
      slab: 0xa7845c, top: 0x2b2219, carcass: 0xe9dcc4, door: 0xb56f3a, cab: 0xdcc9a8,
      plinth: 0x3d3020, dark: 0x17120c, frame: 0xf7f0e2, shelf: 0xd2a86e,
      board: 0xf8f1e2, baseClad: 0x5c3a1e, fill: null
    },
    {
      name: 'Beige & Cream',
      floor: 0xcdbba0, wall: 0xf2ead9, dado: 0xb5a284, rail: 0x84745a, ceil: 0xf5f0e4,
      slab: 0x97876d, top: 0x2d2822, carcass: 0xefe5d2, door: 0xb99a6a, cab: 0xe2d5bd,
      plinth: 0x41392c, dark: 0x181510, frame: 0xf9f4e9, shelf: 0xc4ac86,
      board: 0xf8f3e8, baseClad: 0x54432c, fill: null
    },
    {
      name: 'Pastel Laboratory',
      floor: 0xd5c6cc, wall: 0xf6eef0, dado: 0xc48f9e, rail: 0x966574, ceil: 0xf8f2f4,
      slab: 0xa78e97, top: 0x3a3236, carcass: 0xf3e8ea, door: 0xc9a0b4, cab: 0xe8d8dc,
      plinth: 0x45343a, dark: 0x1a1417, frame: 0xfbf5f7, shelf: 0xcba8b6,
      board: 0xfaf2f4, baseClad: 0x5c3844, fill: null
    },
    {
      name: 'Navy & Grey',
      floor: 0x9fa8b2, wall: 0xdfe4e8, dado: 0x2c4a73, rail: 0x1c3352, ceil: 0xe8ecef,
      slab: 0x737d88, top: 0x131b26, carcass: 0xd5dce2, door: 0x5d7a99, cab: 0xc0c9d2,
      plinth: 0x1e2836, dark: 0x0c1119, frame: 0xf0f3f6, shelf: 0x9aa6b2,
      board: 0xeef2f6, baseClad: 0x16273d, fill: null
    },
    {
      name: 'Forest Green',
      floor: 0x8fa083, wall: 0xdfe6d6, dado: 0x2f5c3a, rail: 0x1d3f26, ceil: 0xe9efe2,
      slab: 0x68785e, top: 0x151d16, carcass: 0xd4ddc6, door: 0x6d9460, cab: 0xbcc9ae,
      plinth: 0x22301f, dark: 0x0d130e, frame: 0xf0f4ea, shelf: 0x94a886,
      board: 0xecf2e6, baseClad: 0x1e3320, fill: null
    },
    {
      name: 'Violet Accents',
      floor: 0xb4aec0, wall: 0xeeeaf2, dado: 0x7a6a9e, rail: 0x544877, ceil: 0xf2eff5,
      slab: 0x8b8299, top: 0x221e2b, carcass: 0xe4dfeb, door: 0x9d8ec2, cab: 0xd2cadd,
      plinth: 0x302a3e, dark: 0x141118, frame: 0xf6f4f9, shelf: 0xb3a8ca,
      board: 0xf3f0f7, baseClad: 0x352a4e, fill: null
    },
    {
      name: 'Copper & Neutral',
      floor: 0xc0b09a, wall: 0xf1ebe1, dado: 0xb06e3f, rail: 0x7e4c28, ceil: 0xf5f0e8,
      slab: 0x9a8570, top: 0x241d17, carcass: 0xe9e0d2, door: 0xc08552, cab: 0xdccfbc,
      plinth: 0x38302a, dark: 0x15110d, frame: 0xf8f3ea, shelf: 0xc9a67e,
      board: 0xf7f2ea, baseClad: 0x5c3c22, fill: null
    },
    {
      name: 'Slate Blue',
      floor: 0x93a5b3, wall: 0xd4dfe6, dado: 0x4a6b88, rail: 0x304d66, ceil: 0xe2eaef,
      slab: 0x6b7d8c, top: 0x18222c, carcass: 0xcbd6de, door: 0x7d97ab, cab: 0xb6c5d0,
      plinth: 0x243140, dark: 0x101820, frame: 0xeef3f7, shelf: 0x9db0be,
      board: 0xebf1f5, baseClad: 0x1c3244, fill: null
    },
    {
      name: 'Rosewood',
      floor: 0xc0a49a, wall: 0xf2e8e2, dado: 0xa8665e, rail: 0x7a453f, ceil: 0xf5ece7,
      slab: 0x96796f, top: 0x2a1f1e, carcass: 0xe9dcd4, door: 0xc99a96, cab: 0xdcc8c0,
      plinth: 0x3a2c2a, dark: 0x161110, frame: 0xf8f1ec, shelf: 0xc5a096,
      board: 0xf7f0eb, baseClad: 0x54302c, fill: null
    },
    {
      name: 'Monochrome Lab',
      floor: 0xb0b0b0, wall: 0xf2f2f2, dado: 0x8c8c8c, rail: 0x5e5e5e, ceil: 0xf7f7f7,
      slab: 0x7d7d7d, top: 0x0d0d0d, carcass: 0xe8e8e8, door: 0xa8a8a8, cab: 0xd8d8d8,
      plinth: 0x2c2c2c, dark: 0x0f0f0f, frame: 0xfafafa, shelf: 0xbdbdbd,
      board: 0xf5f5f5, baseClad: 0x242424, fill: null
    },
    {
      name: 'Sunshine',
      floor: 0xd4c088, wall: 0xf7f0d8, dado: 0xd4a22a, rail: 0x9e7414, ceil: 0xf9f3e0,
      slab: 0xac9560, top: 0x2c2818, carcass: 0xf0e6c8, door: 0xe0b84a, cab: 0xe4d8b0,
      plinth: 0x3e3620, dark: 0x17140c, frame: 0xfaf5e6, shelf: 0xd2ba78,
      board: 0xfaf4e0, baseClad: 0x5c4818, fill: null
    },
    {
      name: 'Coral Reef',
      floor: 0x9cc4bc, wall: 0xe6f0ec, dado: 0xd4725c, rail: 0xa44e3a, ceil: 0xeef4f1,
      slab: 0x76988f, top: 0x152424, carcass: 0xd6e6e0, door: 0xe8907a, cab: 0xc0d8d0,
      plinth: 0x20322e, dark: 0x0e1816, frame: 0xf2f7f5, shelf: 0x9fc0b6,
      board: 0xeef6f2, baseClad: 0x1e4038, fill: null
    },
    {
      name: 'Midnight Research',
      floor: 0x4a4e52, wall: 0x6e7378, dado: 0x3a3e42, rail: 0x24282c, ceil: 0x8a8f94,
      slab: 0x55595d, top: 0x0c0e10, carcass: 0xd8dadc, door: 0x6a6e72, cab: 0xc4c6c8,
      plinth: 0x1a1c1e, dark: 0x08090a, frame: 0xb8bbbd, shelf: 0x565c60,
      board: 0xc9ccce, baseClad: 0x121416, fill: null
    }
  ];

  root.BIO_LAB_THEMES = THEMES;
  if (typeof module === 'object' && module.exports) module.exports = THEMES;
})(typeof window !== 'undefined' ? window : globalThis);
