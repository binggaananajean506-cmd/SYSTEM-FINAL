"use strict";

function validOrganizationProofHeader(header, contentType, extension) {
  if (!Buffer.isBuffer(header)) return false;
  if (contentType === "application/pdf" && extension === "pdf") {
    return header.subarray(0, 5).toString("ascii") === "%PDF-";
  }
  if (contentType === "image/jpeg" && ["jpg", "jpeg"].includes(extension)) {
    return header.length >= 3 && header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff;
  }
  if (contentType === "image/png" && extension === "png") {
    return header.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  }
  return false;
}

module.exports = { validOrganizationProofHeader };
