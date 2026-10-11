"""
GA4 item_category 원값(74종)을 실제 사이트 내비게이션 구조(Wayback Machine 2020-11-06 스냅샷,
shop.googlemerchandisestore.com 확인)를 기준으로 정규화된 카테고리로 매핑한다.

사이트 실제 메뉴 구조:
  New / Apparel(Hats, Kids, Men's/Unisex, Socks, Women's) /
  Lifestyle(Bags, Drinkware, Small Goods) / Stationery(Notebooks, Stickers, Writing) /
  Eco-Friendly / Shop by Brand(Android, Google, #IamRemarkable, YouTube) / Sale / Campus Collection

메뉴에 없는 값(Electronics, Fun, Gift Cards, Black Lives Matter, Miscellaneous 등)은
추측하지 않고 "기타"로 남긴다.
"""

CATEGORY_MAP = {
    # New
    "New": "New", "Home/New/": "New",
    # Apparel
    "Apparel": "Apparel", "Home/Apparel/": "Apparel",
    "Hats": "Apparel/Hats", "Home/Apparel/Hats/": "Apparel/Hats",
    "Kids": "Apparel/Kids", "Home/Apparel/Kids/": "Apparel/Kids",
    "Kid's-Infant/": "Apparel/Kids", "Kid's-Toddler/": "Apparel/Kids", "Kids-Youth/": "Apparel/Kids",
    "Men's / Unisex": "Apparel/Men's", "Home/Apparel/Men's / Unisex/": "Apparel/Men's",
    "Men's T-Shirts": "Apparel/Men's", "Men's T-Shirts/": "Apparel/Men's",
    "Men's Warm Gear": "Apparel/Men's", "Men's Warm Gear/": "Apparel/Men's",
    "Home/Apparel/Socks/": "Apparel/Socks",
    "Women's": "Apparel/Women's", "Home/Apparel/Women's/": "Apparel/Women's",
    "Women's T-Shirts": "Apparel/Women's", "Women's T-Shirts/": "Apparel/Women's",
    "Women's Warm Gear/": "Apparel/Women's",
    # Lifestyle
    "Lifestyle": "Lifestyle", "Lifestyle/": "Lifestyle",
    "Bags": "Lifestyle/Bags", "Lifestyle/Bags/": "Lifestyle/Bags",
    "Backpacks/": "Lifestyle/Bags", "More Bags/": "Lifestyle/Bags", "Shopping and Totes/": "Lifestyle/Bags",
    "Drinkware": "Lifestyle/Drinkware", "Lifestyle/Drinkware/": "Lifestyle/Drinkware",
    "Mugs & Tumblers/": "Lifestyle/Drinkware", "Water Bottles": "Lifestyle/Drinkware", "Water Bottles/": "Lifestyle/Drinkware",
    "Small Goods": "Lifestyle/Small Goods", "Lifestyle/Small Goods/": "Lifestyle/Small Goods",
    # Stationery
    "Stationery": "Stationery", "Home/Stationery/": "Stationery",
    "Notebooks": "Stationery/Notebooks", "Home/Stationery/Notebooks/": "Stationery/Notebooks",
    "Home/Stationery/Stickers/": "Stationery/Stickers",
    "Writing": "Stationery/Writing", "Home/Stationery/Writing/": "Stationery/Writing",
    "Office": "Stationery/Office", "Office/": "Stationery/Office",
    # Eco-Friendly
    "Eco-Friendly": "Eco-Friendly", "Home/Eco-Friendly/": "Eco-Friendly",
    # Shop by Brand
    "Shop by Brand": "Shop by Brand", "Home/Shop by Brand/": "Shop by Brand",
    "Android": "Shop by Brand/Android", "Home/Shop by Brand/Android/": "Shop by Brand/Android",
    "Google": "Shop by Brand/Google", "Home/Shop by Brand/Google/": "Shop by Brand/Google",
    "Home/Shop by Brand/Google Cloud/": "Shop by Brand/Google",
    "Home/Shop by Brand/#IamRemarkable/": "Shop by Brand/#IamRemarkable",
    "YouTube": "Shop by Brand/YouTube", "Home/Shop by Brand/YouTube/": "Shop by Brand/YouTube",
    # Sale
    "Sale": "Sale", "Home/Sale/": "Sale", "Clearance-Accessories/": "Sale",
    # Campus Collection
    "Campus Collection": "Campus Collection", "Home/Campus Collection/": "Campus Collection",
    # 사이트 메뉴에 없는 값 -> 기타 (추측하지 않음)
    "(not set)": "기타/미분류",
    "Accessories": "기타/미분류", "Accessories/": "기타/미분류", "New-Accessories/": "기타/미분류",
    "Electronics/": "기타/미분류", "Electronics/Electronic Accessories/": "기타/미분류",
    "Fun": "기타/미분류", "Fun/": "기타/미분류",
    "Home/Gift Cards/": "기타/미분류",
    "Home/Black Lives Matter/": "기타/미분류",
    "Miscellaneous/": "기타/미분류",
}
