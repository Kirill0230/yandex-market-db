package ru.kirill0230.dto;

public record AddToCartRequest(
        Integer userId,
        Integer productDetailId,
        Integer quantity
) {}