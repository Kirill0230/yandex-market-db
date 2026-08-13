package ru.kirill0230.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import ru.kirill0230.dto.ProductCardDto;
import ru.kirill0230.dto.ProductCardDto.Seller;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Repository
public class ProductCardRepository {

    private static final String SQL = """
            SELECT
                p.product_id,
                p.name,
                p.description,
                p.color,
                p.country_origin,
                p.views_count,
                ps.name AS subcategory_name,
                pc.name AS category_name,
                pd.product_detail_id,
                pd.seller_id,
                pd.price,
                pd.quantity,
                (SELECT AVG(rp.rating)
                 FROM review_products rp
                 WHERE rp.product_detail_id = pd.product_detail_id) AS avg_rating,
                (SELECT COUNT(*)
                 FROM review_products rp
                 WHERE rp.product_detail_id = pd.product_detail_id) AS reviews_count,
                (SELECT COUNT(*)
                 FROM favorites f
                 WHERE f.product_id = p.product_id) AS favorites_count
            FROM product p
            JOIN product_subcategory ps ON ps.product_subcategory_id = p.product_subcategory_id
            JOIN product_category    pc ON pc.product_category_id    = ps.product_category_id
            JOIN product_detail      pd ON pd.product_id             = p.product_id
            WHERE p.product_id = ?
            """;

    private final JdbcTemplate jdbc;

    public ProductCardRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<ProductCardDto> findById(int productId) {
        List<Row> rows = jdbc.query(SQL, (rs, i) -> new Row(
                rs.getInt("product_id"),
                rs.getString("name"),
                rs.getString("description"),
                rs.getString("color"),
                rs.getString("country_origin"),
                (Integer) rs.getObject("views_count"),
                rs.getString("subcategory_name"),
                rs.getString("category_name"),
                rs.getInt("product_detail_id"),
                rs.getInt("seller_id"),
                rs.getBigDecimal("price"),
                rs.getInt("quantity"),
                rs.getBigDecimal("avg_rating"),
                rs.getLong("reviews_count"),
                rs.getLong("favorites_count")
        ), productId);

        if (rows.isEmpty()) {
            return Optional.empty();
        }

        Row first = rows.get(0);
        List<Seller> offers = new ArrayList<>(rows.size());
        for (Row r : rows) {
            offers.add(new Seller(
                    r.productDetailId(),
                    r.sellerId(),
                    r.price(),
                    r.quantity(),
                    r.avgRating(),
                    r.reviewsCount()
            ));
        }

        return Optional.of(new ProductCardDto(
                first.productId(),
                first.name(),
                first.description(),
                first.color(),
                first.countryOrigin(),
                first.viewsCount(),
                first.subcategoryName(),
                first.categoryName(),
                first.favoritesCount(),
                offers
        ));
    }

    private record Row(
            int productId,
            String name,
            String description,
            String color,
            String countryOrigin,
            Integer viewsCount,
            String subcategoryName,
            String categoryName,
            int productDetailId,
            int sellerId,
            BigDecimal price,
            int quantity,
            BigDecimal avgRating,
            long reviewsCount,
            long favoritesCount
    ) {}
}