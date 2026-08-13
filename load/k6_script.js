import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

const USER_MAX = Number(__ENV.USER_MAX || 100);
const PRODUCT_MAX = Number(__ENV.PRODUCT_MAX || 300);
const PRODUCT_DETAIL_MAX = Number(__ENV.PRODUCT_DETAIL_MAX || 600);

function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

function todayIso() {
    return new Date().toISOString().slice(0, 10);
}

function daysAgoIso(days) {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date.toISOString().slice(0, 10);
}

export const options = {
    scenarios: {
        oltp_profile: {
            executor: 'ramping-vus',
            exec: 'oltp',
            stages: [
                { duration: '1m', target: 5 },
                { duration: '3m', target: 5 },
                { duration: '30s', target: 0 }
            ]
        },

        olap_profile: {
            executor: 'ramping-vus',
            exec: 'olap',
            stages: [
                { duration: '1m', target: 2 },
                { duration: '3m', target: 2 },
                { duration: '30s', target: 0 }
            ]
        },

        time_series_profile: {
            executor: 'ramping-vus',
            exec: 'timeSeries',
            stages: [
                { duration: '1m', target: 3 },
                { duration: '3m', target: 3 },
                { duration: '30s', target: 0 }
            ]
        }
    },

    thresholds: {
        http_req_failed: ['rate<0.05'],
        http_req_duration: ['p(95)<2000']
    }
};

export function oltp() {
    const productId = rand(1, PRODUCT_MAX);
    const userId = rand(1, USER_MAX);
    const productDetailId = rand(1, PRODUCT_DETAIL_MAX);

    const headers = {
        'Content-Type': 'application/json'
    };

    const responses = http.batch([
        [
            'GET',
            `${BASE_URL}/products/${productId}`,
            null,
            { tags: { profile: 'oltp', endpoint: 'product-card' } }
        ],
        [
            'POST',
            `${BASE_URL}/cart`,
            JSON.stringify({
                userId: userId,
                productDetailId: productDetailId,
                quantity: rand(1, 3)
            }),
            {
                headers: headers,
                tags: { profile: 'oltp', endpoint: 'cart-add' }
            }
        ]
    ]);

    check(responses[0], {
        'product card status is 200 or 404': (r) => r.status === 200 || r.status === 404
    });

    check(responses[1], {
        'cart add status is 201': (r) => r.status === 201
    });

    sleep(1);
}

export function olap() {
    const from = daysAgoIso(365);
    const to = todayIso();

    const responses = http.batch([
        [
            'GET',
            `${BASE_URL}/analytics/top-sellers?from=${from}&to=${to}`,
            null,
            { tags: { profile: 'olap', endpoint: 'top-sellers' } }
        ],
        [
            'GET',
            `${BASE_URL}/analytics/revenue-by-category?from=${from}&to=${to}`,
            null,
            { tags: { profile: 'olap', endpoint: 'revenue-by-category' } }
        ]
    ]);

    check(responses[0], {
        'top sellers status is 200': (r) => r.status === 200
    });

    check(responses[1], {
        'revenue by category status is 200': (r) => r.status === 200
    });

    sleep(2);
}

export function timeSeries() {
    const productId = rand(1, PRODUCT_MAX);
    const productDetailId = rand(1, PRODUCT_DETAIL_MAX);

    const headers = {
        'Content-Type': 'application/json'
    };

    const newPrice = rand(100, 50000) + Math.random();

    const responses = http.batch([
        [
            'GET',
            `${BASE_URL}/products/${productId}/price-history?days=365`,
            null,
            { tags: { profile: 'time-series', endpoint: 'price-history' } }
        ],
        [
            'POST',
            `${BASE_URL}/events/price-change`,
            JSON.stringify({
                productDetailId: productDetailId,
                price: Number(newPrice.toFixed(2))
            }),
            {
                headers: headers,
                tags: { profile: 'time-series', endpoint: 'price-change-event' }
            }
        ]
    ]);

    check(responses[0], {
        'price history status is 200': (r) => r.status === 200
    });

    check(responses[1], {
        'price event status is 202': (r) => r.status === 202
    });

    sleep(1);
}