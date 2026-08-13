package ru.kirill0230.dto;

import java.math.BigDecimal;
import java.util.List;

public record ProductCardDto(
        Integer productId,
        String name,
        String description,
        String color,
        String countryOrigin,
        Integer viewsCount,
        String subcategoryName,
        String categoryName,
        Long favoritesCount,
        List<Seller> offers
) {
    public record Seller(
            Integer productDetailId,
            Integer sellerId,
            BigDecimal price,
            Integer quantity,
            BigDecimal avgRating,
            Long reviewsCount
    ) {}
}