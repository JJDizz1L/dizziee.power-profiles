// Run with: node --test tests/
const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

test("cleanProfileName accepts plain names and rejects bad values", () => {
  assert.equal(Model.cleanProfileName("balanced"), "balanced")
  assert.equal(Model.cleanProfileName("  performance  "), "performance")
  assert.equal(Model.cleanProfileName(""), "")
  assert.equal(Model.cleanProfileName("x".repeat(65)), "")
  assert.equal(Model.cleanProfileName(null), "")
  assert.equal(Model.cleanProfileName({ name: "balanced" }), "")
})

test("parseProfiles trims, de-duplicates and caps the list", () => {
  const raw = [
    "balanced\t1",
    "balanced\t0",
    "",
    "  performance\t0  ",
    "x".repeat(65) + "\t0",
    ...Array.from({ length: 20 }, (_, index) => "profile-" + index + "\t0")
  ].join("\n")
  const parsed = Model.parseProfiles(raw, 0)
  assert.equal(parsed.profiles[0], "balanced")
  assert.equal(parsed.profiles[1], "performance")
  assert.equal(parsed.profiles.filter(name => name === "balanced").length, 1)
  assert.equal(parsed.profiles.length, Model.MAX_PROFILES)
  assert.equal(parsed.activeProfile, "balanced")
})

test("parseProfiles handles an empty response", () => {
  assert.deepEqual(Model.parseProfiles("", 3), {
    profiles: [],
    activeProfile: "",
    profileIndex: 0
  })
})

test("selectProfileIndex clamps at both ends", () => {
  assert.equal(Model.selectProfileIndex(0, 1, ["a", "b"]), 1)
  assert.equal(Model.selectProfileIndex(0, -1, ["a", "b"]), 0)
  assert.equal(Model.selectProfileIndex(1, 1, ["a", "b"]), 1)
  assert.equal(Model.selectProfileIndex(5, 1, []), 0)
})

test("profileIcon covers the three standard profiles", () => {
  assert.notEqual(Model.profileIcon("power-saver"), Model.profileIcon("balanced"))
  assert.notEqual(Model.profileIcon("balanced"), Model.profileIcon("performance"))
  assert.equal(Model.profileIcon("unknown"), Model.profileIcon("unknown"))
})
