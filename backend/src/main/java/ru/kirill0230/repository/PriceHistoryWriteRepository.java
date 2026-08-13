package ru.kirill0230.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;

@Repository
@RequiredArgsConstructor
public class PriceHistoryWriteRepository {

    private static final String SQL = """
            INSERT INTO product_price_history (product_detail_id, price, change_date)
            VALUES (?, ?, NOW())
            """;

    private final JdbcTemplate jdbc;

    public void logPriceChange(int productDetailId, BigDecimal price) {
        jdbc.update(SQL, productDetailId, price);
    }
}