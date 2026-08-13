package ru.kirill0230.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record PriceHistoryPointDto(
        OffsetDateTime changeDate,
        BigDecimal price,
        BigDecimal prevPrice
) {}