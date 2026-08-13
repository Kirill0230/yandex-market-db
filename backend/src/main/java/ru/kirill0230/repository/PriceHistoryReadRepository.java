package ru.kirill0230.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.PriceHistoryPointDto;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class PriceHistoryReadRepository {

    private static final String SQL = """
            SELECT
                pph.change_date,
                pph.price,
                LAG(pph.price) OVER (ORDER BY pph.change_date) AS prev_price
            FROM product_price_history pph
            JOIN product_detail        pd ON pd.product_detail_id = pph.product_detail_id
            WHERE pd.product_id  = ?
              AND pph.change_date >= NOW() - (? || ' days')::interval
            ORDER BY pph.change_date
            """;

    private final JdbcTemplate jdbc;

    public List<PriceHistoryPointDto> findHistory(int productId, int days) {
        return jdbc.query(SQL, (rs, i) -> new PriceHistoryPointDto(
                rs.getObject("change_date", OffsetDateTime.class),
                rs.getBigDecimal("price"),
                rs.getBigDecimal("prev_price")
        ), productId, days);
    }
}