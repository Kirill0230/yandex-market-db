package ru.kirill0230.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import lombok.RequiredArgsConstructor;

@Repository
@RequiredArgsConstructor
public class CartRepository {

    private static final String SQL = """
            INSERT INTO cart_items (user_id, product_detail_id, quantity)
            VALUES (?, ?, ?)
            RETURNING cart_item_id
            """;

    private final JdbcTemplate jdbc;

    public Integer addToCart(int userId, int productDetailId, int quantity) {
        return jdbc.queryForObject(SQL, Integer.class, userId, productDetailId, quantity);
    }
}