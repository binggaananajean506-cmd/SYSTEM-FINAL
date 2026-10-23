// Local seals supplied for Barili. The three barangays without a supplied seal
// use the Municipality of Barili seal until an official image is available.
const sealFiles = {
  bagakay: "bagakay.jpg", balao: "balao.jpg", bolocboloc: "bolocboloc.jpg",
  budbud: "budbud.png", bugtongkawayan: "bugtong_kawayan.jpg",
  cabcaban: "cabcaban.jpg", cagay: "cagay.png", campangga: "campangga.jpg",
  candugay: "candugay.jpg", dakit: "dakit.jpg", giloctog: "giloctog.png",
  guibuangan: "guibuangan.jpg", giwanon: "guiwanon.jpg",
  gunting: "gunting.jpg", hilasgasan: "hilasgasan.jpg",
  japitan: "japitan.jpg", kalubihan: "kalubihan.png",
  kangdampas: "kangdampas.jpg", luhod: "luhod.png", lupo: "lupo.png",
  maghanoy: "maghanoy.png", maigang: "maigang.jpg",
  malolos: "malolos.jpg", mantalongon: "mantalongon.jpg",
  mantayupan: "mantayupan.jpg", mayana: "mayana.jpg",
  minolos: "minolos.jpg", nabunturan: "nabunturan.jpg",
  nasipit: "nasipit.jpg", pancil: "pancil.png",
  pangpang: "pangpang.png", paril: "paril.jpg", patupat: "patupat.jpg",
  poblacion: "poblacion.jpg", sanrafael: "san_rafael.jpg",
  santaana: "santa_ana.jpg", talot: "tal_ot.png",
  tubod: "tubod.jpg", vito: "vito.png"
};
const knownBarangays = new Set([...Object.keys(sealFiles), "azucena", "luyo", "sayaw"]);

export const MUNICIPALITY_SEAL = "assets/barili-logoo.png";
const missingSeals = new Set();

function barangayKey(value) {
  let key = String(value || "").trim().toLowerCase()
    .replace(/^(?:(?:barangay|brgy|bgy|barili)[\s_:.-]+)+/, "")
    .replace(/[^a-z0-9]/g, "");
  if (key === "guiwanon") key = "giwanon";
  return key;
}

function firstKnown(values) {
  for (const value of values) {
    const key = barangayKey(value);
    if (knownBarangays.has(key)) return key;
  }
  return "";
}

// The recipient/case identity takes precedence over the reporting resident.
export function barangayLogoForCase(item, summons = null) {
  const isBarangay = item?.kind === "complaint"
    || item?.recipientType === "barangay"
    || Boolean(item?.receivingBarangayId || item?.receivingBarangayName)
    || String(item?.recipientId || "").startsWith("barangay-")
    || Boolean(summons);
  if (!isBarangay) return null;

  const ids = [item?.receivingBarangayId, item?.recipientId,
    item?.recipientBarangayId, summons?.barangayId, item?.barangayId];
  const names = [item?.receivingBarangayName, summons?.barangay,
    item?.department, item?.complaint?.barangay, item?.barangay];
  const key = firstKnown(ids) || firstKnown(names);
  if (sealFiles[key]) return `assets/barangays/${sealFiles[key]}`;

  const identity = [...ids, ...names].find((value) => String(value || "").trim()) || "unspecified barangay";
  if (!missingSeals.has(identity)) {
    missingSeals.add(identity);
    console.warn(`[BarangayLogos] No local seal for ${identity}; using municipality seal.`);
  }
  return MUNICIPALITY_SEAL;
}
