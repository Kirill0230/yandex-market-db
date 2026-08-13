package ru.kirill0230.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.CategoryRevenueDto;

import java.time.LocalDate;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class RevenueByCategoryRepository {

    private static final String SQL = """
        SELECT
            product_category_id,
            category_name,
            orders_count,
            revenue,
            avg_order_line
        FROM mv_revenue_by_category
        ORDER BY revenue DESC
        """;

    private final JdbcTemplate jdbc;
    
    public List<CategoryRevenueDto> findRevenueByCategory(LocalDate from, LocalDate to) {
    return jdbc.query(SQL, (rs, i) -> new CategoryRevenueDto(
            rs.getInt("product_category_id"),
            rs.getString("category_name"),
            rs.getLong("orders_count"),
            rs.getBigDecimal("revenue"),
            rs.getBigDecimal("avg_order_line")
    ));
}
}