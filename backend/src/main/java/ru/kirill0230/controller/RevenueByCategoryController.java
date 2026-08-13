package ru.kirill0230.controller;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.CategoryRevenueDto;
import ru.kirill0230.repository.RevenueByCategoryRepository;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/analytics/revenue-by-category")
@RequiredArgsConstructor
public class RevenueByCategoryController {

    private final RevenueByCategoryRepository repository;

    @GetMapping
    public List<CategoryRevenueDto> get(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return repository.findRevenueByCategory(from, to);
    }
}