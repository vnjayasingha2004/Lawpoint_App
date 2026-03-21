function nowIso() {
  return new Date().toISOString();
}

function addMinutes(iso, minutes) {
  return new Date(new Date(iso).getTime() + minutes * 60 * 1000).toISOString();
}

function isWithinWindow(targetIso, fromIso, untilIso) {
  const target = new Date(targetIso).getTime();
  return target >= new Date(fromIso).getTime() && target <= new Date(untilIso).getTime();
}

module.exports = { nowIso, addMinutes, isWithinWindow };
