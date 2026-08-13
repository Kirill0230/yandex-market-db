package ru.kirill0230.dto;

import java.math.BigDecimal;

public record PriceChangeEvent(
        Integer productDetailId,
        BigDecimal price
) {}