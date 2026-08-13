package ru.kirill0230.controller;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import lombok.RequiredArgsConstructor;
import ru.kirill0230.dto.SellerRankDto;
import ru.kirill0230.repository.TopSellersRepository;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/analytics/top-sellers")
@RequiredArgsConstructor
public class TopSellersController {

    private final TopSellersRepository repository;

    @GetMapping
    public List<SellerRankDto> get(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to
    ) {
        return repository.findTopSellers(from, to);
    }
}