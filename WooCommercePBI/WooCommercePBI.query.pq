// Use this file to write queries to test your data connector
let
    result = WooCommercePBI.getProducts("https://www.snuffies.nl", #date(2020, 1, 1), #date(2021, 9, 21))
in
    result