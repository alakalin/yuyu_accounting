import 'package:flutter/material.dart';

class IconUtil {
  static IconData getCategoryIcon(String name) {
    switch (name) {
      case '餐饮':
        return Icons.restaurant;
      case '交通':
        return Icons.directions_car;
      case '购物':
        return Icons.shopping_cart;
      case '娱乐':
        return Icons.movie;
      case '住房':
        return Icons.home_filled;
      case '日常':
        return Icons.local_grocery_store;
      case '医疗':
        return Icons.local_hospital;
      case '教育':
        return Icons.school;

      case '工资':
        return Icons.account_balance_wallet;
      case '兼职':
        return Icons.work;
      case '理财':
        return Icons.trending_up;
      case '礼金':
        return Icons.card_giftcard;
      case '其他':
        return Icons.category;

      default:
        return Icons.monetization_on;
    }
  }
}
