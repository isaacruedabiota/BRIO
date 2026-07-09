"""
HTTP client for the Open Food Facts API v2.
Returns domain entities — never exposes the API's JSON structure.
"""
from __future__ import annotations

import logging
from typing import Optional

import requests

from apps.nutrition.domain.entities import FoodItem, FoodSource

logger = logging.getLogger(__name__)

_BASE    = "https://world.openfoodfacts.org"
_FIELDS  = "product_name,brands,code,nutriments"
_TIMEOUT = 8  # seconds
_HEADERS = {"User-Agent": "BRIO-App/0.1 (contacto@brio.app)"}


class OpenFoodFactsClient:

    def search(self, query: str, country: str = "es", limit: int = 20) -> list[FoodItem]:
        try:
            resp = requests.get(
                f"{_BASE}/cgi/search.pl",
                params={
                    "search_terms":  query,
                    "search_simple": 1,
                    "action":        "process",
                    "json":          1,
                    "page_size":     limit,
                    "cc":            country,
                    "lc":            "es",
                },
                headers=_HEADERS,
                timeout=_TIMEOUT,
            )
            resp.raise_for_status()
        except requests.RequestException as e:
            logger.warning("Open Food Facts search falló: %s", e)
            return []

        products = resp.json().get("products") or []
        return [item for p in products if (item := self._parse(p)) is not None]

    def get_by_barcode(self, barcode: str) -> Optional[FoodItem]:
        try:
            resp = requests.get(
                f"{_BASE}/api/v2/product/{barcode}.json",
                params={"fields": _FIELDS},
                headers=_HEADERS,
                timeout=_TIMEOUT,
            )
            resp.raise_for_status()
        except requests.RequestException as e:
            logger.warning("Open Food Facts barcode falló (%s): %s", barcode, e)
            return None

        data = resp.json()
        if data.get("status") != 1:
            return None
        return self._parse(data.get("product", {}))

    # Internal parser.

    @staticmethod
    def _parse(product: dict) -> Optional[FoodItem]:
        name = (product.get("product_name") or "").strip()
        if not name:
            return None

        n = product.get("nutriments", {})

        def _f(key: str) -> float:
            try:
                return float(n.get(key, 0) or 0)
            except (ValueError, TypeError):
                return 0.0

        kcal = _f("energy-kcal_100g")
        if kcal <= 0:
            # Try converting from kJ if there's no kcal.
            kj = _f("energy_100g")
            kcal = round(kj / 4.184, 1) if kj > 0 else 0.0

        return FoodItem(
            name             = name,
            brand            = (product.get("brands") or "").strip() or None,
            barcode          = product.get("code") or None,
            kcal_per_100g    = kcal,
            protein_per_100g = _f("proteins_100g"),
            carbs_per_100g   = _f("carbohydrates_100g"),
            fat_per_100g     = _f("fat_100g"),
            fiber_per_100g   = _f("fiber_100g"),
            source           = FoodSource.OPEN_FOOD_FACTS,
            verified         = False,
        )
