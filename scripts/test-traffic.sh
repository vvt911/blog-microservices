#!/bin/bash

# Mô phỏng các tình huống thực tế với tỷ lệ phân bố khác nhau

# Tạo 500 requests với các loại khác nhau
for i in {1..500}; do
  # Phân chia các loại request theo tỷ lệ thực tế
  case $((i % 10)) in
    0|1|2|3|4)  # 50% - Các yêu cầu GET bình thường (đọc dữ liệu)
      # Danh sách các endpoint phổ biến
      endpoints=("api/blogs" "api/users" "api/blogs/1/comments" "api/blogs/2/comments")
      # Chọn ngẫu nhiên một endpoint
      endpoint=${endpoints[$((RANDOM % ${#endpoints[@]}))]}
      curl -s http://localhost:8080/$endpoint > /dev/null
      ;;
    5|6)  # 20% - Các yêu cầu POST (tạo dữ liệu mới)
      if [ $((RANDOM % 2)) -eq 0 ]; then
        # Tạo blog mới
        curl -s http://localhost:8080/api/blogs -X POST -H "Content-Type: application/json" -d '{"title":"Blog'$i'","content":"Content'$i'","author":"Author'$i'"}' > /dev/null
      else
        # Tạo user mới
        curl -s http://localhost:8080/api/users -X POST -H "Content-Type: application/json" -d '{"name":"User'$i'","email":"user'$i'@test.com"}' > /dev/null
      fi
      ;;
    7)  # 10% - Các yêu cầu PUT (cập nhật dữ liệu)
      curl -s http://localhost:8080/api/blogs/1 -X PUT -H "Content-Type: application/json" -d '{"title":"Updated'$i'","content":"Updated Content","author":"Updated Author"}' > /dev/null
      ;;
    8)  # 10% - Các yêu cầu lỗi (404/500) để test xử lý lỗi
      errors=("api/nonexistent" "api/blogs/999999" "api/users/invalid" "api/comments/xyz")
      error=${errors[$((RANDOM % ${#errors[@]}))]}
      curl -s http://localhost:8080/$error > /dev/null
      ;;
    9)  # 10% - Các yêu cầu DELETE (xóa dữ liệu)
      curl -s http://localhost:8080/api/blogs/2 -X DELETE > /dev/null
      ;;
  esac
  
  # Tạo độ trễ ngẫu nhiên giữa 0.1-2 giây để mô phỏng hành vi người dùng thực
  sleep $(awk 'BEGIN{print rand()*1.9+0.1}')
  
  # Hiển thị tiến trình mỗi 50 requests
  [ $((i % 50)) -eq 0 ] && echo "Đã tạo $i requests..."
done

echo "🚀 Bộ tạo lưu lượng đã khởi động! Chạy 'pkill -f curl' để dừng."
