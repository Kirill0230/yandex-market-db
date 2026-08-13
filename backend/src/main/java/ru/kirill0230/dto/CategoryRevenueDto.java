package ru.kirill0230.dto;

import java.math.BigDecimal;

public record CategoryRevenueDto(
        Integer categoryId,
        String categoryName,
        Long ordersCount,
        BigDecimal revenue,
        BigDecimal avgOrderLine
) {}