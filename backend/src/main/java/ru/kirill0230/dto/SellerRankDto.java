package ru.kirill0230.dto;

import java.math.BigDecimal;

public record SellerRankDto(
        Integer sellerId,
        String sellerLogin,
        BigDecimal revenue,
        Long revenueRank,
        BigDecimal revenueShare
) {}