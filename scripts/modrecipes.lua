local ModImagesAtlas = "images/modimages.xml"

Recipe(
  "playerhouse_city",
  {
    Ingredient("boards", 4),
    Ingredient("cutstone", 3),
    Ingredient("goldnugget", 3)
  },
  RECIPETABS.TOWN,
  TECH.SCIENCE_TWO,
  "playerhouse_city_placer"
).atlas = ModImagesAtlas
