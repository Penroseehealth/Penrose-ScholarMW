/* Licence and provenance gate for scientific assets (P1-003).
 *
 * The rule this module exists to enforce: never imply an asset is free to
 * redistribute unless its licence actually says so. Platforms bundle many
 * licences (e.g. Bioicons hosts CC0 and CC-BY artwork side by side; Servier
 * Medical Art is CC-BY; Reactome data is CC0 but its diagrams are not all the
 * same), so terms are evaluated per asset, never per platform.
 *
 * Pure JS: no THREE / no DOM, so both the browser and the Node unit tests use
 * the same logic. Every function is deterministic.
 *
 * Redistribution classes
 *   open          - public-domain / CC0 style; free to redistribute
 *   attribution   - free to redistribute WITH required attribution preserved
 *   restricted    - redistribution not permitted by the stated licence
 *   unverified    - licence or source unknown; treat as restricted
 *
 * Only `open` and `attribution` assets may be packaged for redistribution. An
 * `attribution` asset additionally requires non-empty attribution text.
 */
"use strict";

/* Canonical licence table. Keys are lower-cased, punctuation-normalised
   identifiers. `redistribution` is the class above. This is deliberately a
   small, explicit allow-list: anything not present is `unverified`. */
var LICENCES = {
  "cc0": { id: "cc0", label: "CC0 1.0 (public domain dedication)", redistribution: "open", url: "https://creativecommons.org/publicdomain/zero/1.0/" },
  "public domain": { id: "public-domain", label: "Public domain", redistribution: "open", url: "" },
  "publicdomain": { id: "public-domain", label: "Public domain", redistribution: "open", url: "" },
  "cc-by": { id: "cc-by", label: "CC BY (attribution)", redistribution: "attribution", url: "https://creativecommons.org/licenses/by/4.0/" },
  "cc by": { id: "cc-by", label: "CC BY (attribution)", redistribution: "attribution", url: "https://creativecommons.org/licenses/by/4.0/" },
  "cc-by-4.0": { id: "cc-by", label: "CC BY 4.0", redistribution: "attribution", url: "https://creativecommons.org/licenses/by/4.0/" },
  "cc-by-sa": { id: "cc-by-sa", label: "CC BY-SA (share-alike)", redistribution: "restricted", url: "https://creativecommons.org/licenses/by-sa/4.0/" },
  "cc-by-nc": { id: "cc-by-nc", label: "CC BY-NC (non-commercial)", redistribution: "restricted", url: "https://creativecommons.org/licenses/by-nc/4.0/" },
  "cc-by-nd": { id: "cc-by-nd", label: "CC BY-ND (no derivatives)", redistribution: "restricted", url: "https://creativecommons.org/licenses/by-nd/4.0/" },
  "all rights reserved": { id: "all-rights-reserved", label: "All rights reserved", redistribution: "restricted", url: "" },
  "mit": { id: "mit", label: "MIT License", redistribution: "attribution", url: "https://opensource.org/licenses/MIT" },
  "apache-2.0": { id: "apache-2.0", label: "Apache License 2.0", redistribution: "attribution", url: "https://www.apache.org/licenses/LICENSE-2.0" },
};

function normalizeId(s) {
  return String(s == null ? "" : s).trim().toLowerCase().replace(/[()]/g, "").replace(/\s+/g, " ").trim();
}

/* Look up an explicit licence identifier/string. Returns null when unknown. */
function lookupLicence(raw) {
  if (!raw) return null;
  var key = normalizeId(raw);
  if (LICENCES[key]) return LICENCES[key];
  /* tolerate "CC BY 4.0 International" and similar suffix forms */
  for (var k in LICENCES) {
    if (key === k || key.indexOf(k + " ") === 0) return LICENCES[k];
  }
  return null;
}

/* Evaluate an asset's licence + attribution and produce a gate decision.
   Returns { class, id, label, url, attribution, redistributable, reason }.
   `redistributable` requires: a known licence of class open/attribution, AND
   for class attribution, non-empty attribution text, AND the asset not being
   explicitly flagged for review. */
function evaluateLicence(asset) {
  var a = asset || {};
  var entry = lookupLicence(a.licenceId || a.licence);
  var attribution = String(a.attribution == null ? "" : a.attribution).trim();
  var out = {
    class: "unverified",
    id: null,
    label: a.licence || "Unknown licence",
    url: "",
    attribution: attribution,
    redistributable: false,
    reason: "",
  };
  if (entry) {
    out.class = entry.redistribution;
    out.id = entry.id;
    out.label = entry.label;
    out.url = entry.url || "";
  }
  if (a.needsReview === true) {
    out.class = "unverified";
    out.reason = "flagged for licence review";
    return out;
  }
  if (out.class === "open") {
    out.redistributable = true;
    out.reason = "open licence - free to redistribute";
  } else if (out.class === "attribution") {
    if (attribution) {
      out.redistributable = true;
      out.reason = "redistributable with attribution preserved";
    } else {
      out.redistributable = false;
      out.reason = "attribution required but missing - cannot redistribute until provided";
    }
  } else if (out.class === "restricted") {
    out.reason = "licence restricts redistribution";
  } else {
    out.reason = "licence unverified - treat as restricted";
  }
  return out;
}

/* Convenience predicate used by the packaging guard. */
function canRedistribute(asset) {
  return evaluateLicence(asset).redistributable === true;
}

/* Human-facing provenance string, always shown with an imported asset. */
function provenanceLine(asset) {
  var a = asset || {};
  var ev = evaluateLicence(a);
  var parts = [];
  if (a.provider) parts.push(a.provider);
  parts.push(ev.label);
  if (ev.attribution) parts.push("(c) " + ev.attribution);
  if (a.sourceUrl) parts.push(a.sourceUrl);
  return parts.join(" - ");
}

export { LICENCES, lookupLicence, evaluateLicence, canRedistribute, provenanceLine, normalizeId };
