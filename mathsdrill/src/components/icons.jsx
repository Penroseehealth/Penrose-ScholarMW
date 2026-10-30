const Svg = ({ size = 18, children, ...rest }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.75"
    strokeLinecap="round"
    strokeLinejoin="round"
    aria-hidden="true"
    focusable="false"
    {...rest}
  >
    {children}
  </svg>
);

export const IconDashboard = (p) => (
  <Svg {...p}>
    <rect x="3" y="3" width="7" height="7" rx="1.5" />
    <rect x="14" y="3" width="7" height="7" rx="1.5" />
    <rect x="3" y="14" width="7" height="7" rx="1.5" />
    <rect x="14" y="14" width="7" height="7" rx="1.5" />
  </Svg>
);

export const IconPractice = (p) => (
  <Svg {...p}>
    <path d="M4 5h16v14H4z" />
    <path d="M8 9h8M8 13h5" />
  </Svg>
);

export const IconSolve = (p) => (
  <Svg {...p}>
    <path d="M4 20l5-1 9-9a2.1 2.1 0 0 0-3-3l-9 9z" />
    <path d="M14 5l3 3" />
  </Svg>
);

export const IconProgress = (p) => (
  <Svg {...p}>
    <path d="M4 19V9M10 19V5M16 19v-7M22 19H2" />
  </Svg>
);

export const IconPapers = (p) => (
  <Svg {...p}>
    <path d="M6 3h9l4 4v14H6z" />
    <path d="M15 3v4h4M9 12h7M9 16h7" />
  </Svg>
);

export const IconSettings = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V21a2 2 0 1 1-4 0v-.1A1.7 1.7 0 0 0 8.9 19a1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 5 8.9a1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H10a1.7 1.7 0 0 0 1-1.6V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V10a1.7 1.7 0 0 0 1.6 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
  </Svg>
);

export const IconSelect = (p) => (
  <Svg {...p}>
    <path d="M5 3l6 17 2.4-6.6L20 11z" />
  </Svg>
);

export const IconPen = (p) => (
  <Svg {...p}>
    <path d="M4 20l5-1 10-10a2.1 2.1 0 0 0-3-3L6 16z" />
    <path d="M14 6l3 3" />
  </Svg>
);

export const IconShape = (p) => (
  <Svg {...p}>
    <path d="M12 3l9 16H3z" />
  </Svg>
);

export const IconText = (p) => (
  <Svg {...p}>
    <path d="M5 5h14M12 5v14M9 19h6" />
  </Svg>
);

export const IconMath = (p) => (
  <Svg {...p}>
    <path d="M4 7h6M7 4v6M14 6l6 6M20 6l-6 6M4 16h6M4 20h6" />
  </Svg>
);

export const IconEraser = (p) => (
  <Svg {...p}>
    <path d="M8 20h11" />
    <path d="M15.5 3.5l5 5a2 2 0 0 1 0 2.8L11 21H6l-2.5-2.5a2 2 0 0 1 0-2.8L13 4.5a2 2 0 0 1 2.5-1z" />
  </Svg>
);

export const IconLasso = (p) => (
  <Svg {...p}>
    <path d="M12 4c4.4 0 8 2.5 8 5.6 0 3-3.6 5.5-8 5.5s-8-2.5-8-5.5C4 6.5 7.6 4 12 4z" />
    <path d="M8 15.2V19a2 2 0 0 0 3.4 1.4" />
  </Svg>
);

export const IconTrash = (p) => (
  <Svg {...p}>
    <path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13M10 11v6M14 11v6" />
  </Svg>
);

export const IconUndo = (p) => (
  <Svg {...p}>
    <path d="M9 7L4 12l5 5" />
    <path d="M4 12h9a6 6 0 0 1 6 6" />
  </Svg>
);

export const IconRedo = (p) => (
  <Svg {...p}>
    <path d="M15 7l5 5-5 5" />
    <path d="M20 12h-9a6 6 0 0 0-6 6" />
  </Svg>
);

export const IconZoomIn = (p) => (
  <Svg {...p}>
    <circle cx="11" cy="11" r="7" />
    <path d="M20 20l-3.6-3.6M11 8v6M8 11h6" />
  </Svg>
);

export const IconZoomOut = (p) => (
  <Svg {...p}>
    <circle cx="11" cy="11" r="7" />
    <path d="M20 20l-3.6-3.6M8 11h6" />
  </Svg>
);

export const IconFit = (p) => (
  <Svg {...p}>
    <path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5" />
  </Svg>
);

export const IconFocus = (p) => (
  <Svg {...p}>
    <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" />
    <circle cx="12" cy="12" r="2.6" />
  </Svg>
);

export const IconSparkle = (p) => (
  <Svg {...p}>
    <path d="M12 3l1.9 4.9L19 9.8l-5.1 1.9L12 17l-1.9-5.3L5 9.8l5.1-1.9z" />
    <path d="M18.5 15l.9 2.2 2.1.8-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.8z" />
  </Svg>
);

export const IconUpload = (p) => (
  <Svg {...p}>
    <path d="M12 16V4M8 8l4-4 4 4" />
    <path d="M4 16v3h16v-3" />
  </Svg>
);

export const IconCloud = (p) => (
  <Svg {...p}>
    <path d="M7 18a4 4 0 0 1-.4-8A5.6 5.6 0 0 1 17.4 9 3.7 3.7 0 0 1 17 18z" />
    <path d="M12 15V9M9.6 11.4L12 9l2.4 2.4" />
  </Svg>
);

export const IconSend = (p) => (
  <Svg {...p}>
    <path d="M21 3L3 10.5l7 2.6 2.6 7z" />
  </Svg>
);

export const IconLine = (p) => (
  <Svg {...p}>
    <path d="M4 20L20 4" />
  </Svg>
);

export const IconArrow = (p) => (
  <Svg {...p}>
    <path d="M4 20L20 4M13 4h7v7" />
  </Svg>
);

export const IconRect = (p) => (
  <Svg {...p}>
    <rect x="4" y="6" width="16" height="12" rx="1.5" />
  </Svg>
);

export const IconCircle = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="8" />
  </Svg>
);

export const IconPolygon = (p) => (
  <Svg {...p}>
    <path d="M12 3l8 5.5-3 9.5H7L4 8.5z" />
  </Svg>
);

export const IconLabel = (p) => (
  <Svg {...p}>
    <path d="M4 4h10l6 6v10H4z" />
    <circle cx="9" cy="10" r="1.4" />
  </Svg>
);

export const IconSave = (p) => (
  <Svg {...p}>
    <path d="M5 3h11l3 3v15H5z" />
    <path d="M8 3v6h8V3M8 15h8" />
  </Svg>
);

export const IconSun = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="4" />
    <path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M19 5l-1.5 1.5M6.5 17.5L5 19" />
  </Svg>
);

export const IconMoon = (p) => (
  <Svg {...p}>
    <path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5z" />
  </Svg>
);

export const IconDuplicate = (p) => (
  <Svg {...p}>
    <rect x="8" y="8" width="12" height="12" rx="1.5" />
    <path d="M16 8V4H4v12h4" />
  </Svg>
);

export const IconLayers = (p) => (
  <Svg {...p}>
    <path d="M12 3l9 5-9 5-9-5z" />
    <path d="M3 13l9 5 9-5" />
  </Svg>
);

export const IconPlay = (p) => (
  <Svg {...p}>
    <path d="M7 4l12 8-12 8z" />
  </Svg>
);
