package ru.kirill0230.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.SellerRankDto;

import java.time.LocalDate;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class TopSellersRepository {

    private static final String SQL = """
            SELECT
                s.seller_id,
                u.login AS seller_login,
                SUM(od.quantity * pd.price)                                  AS revenue,
                RANK() OVER (ORDER BY SUM(od.quantity * pd.price) DESC)      AS revenue_rank,
                SUM(od.quantity * pd.price)
                    / NULLIF(SUM(SUM(od.quantity * pd.price)) OVER (), 0)    AS revenue_share
            FROM order_detail   od
            JOIN order_header   oh ON oh.order_header_id   = od.order_header_id
            JOIN product_detail pd ON pd.product_detail_id = od.product_detail_id
            JOIN seller         s  ON s.seller_id          = pd.seller_id
            JOIN users          u  ON u.user_id            = s.user_id
            WHERE oh.order_date BETWEEN ? AND ?
            GROUP BY s.seller_id, u.login
            ORDER BY revenue DESC
            LIMIT 50
            """;

    private final JdbcTemplate jdbc;

    public List<SellerRankDto> findTopSellers(LocalDate from, LocalDate to) {
        return jdbc.query(SQL, (rs, i) -> new SellerRankDto(
                rs.getInt("seller_id"),
                rs.getString("seller_login"),
                rs.getBigDecimal("revenue"),
                rs.getLong("revenue_rank"),
                rs.getBigDecimal("revenue_share")
        ), from, to);
    }
}