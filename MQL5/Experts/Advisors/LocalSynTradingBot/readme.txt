tạo Symbolic Link tới Data folder của MetaEditor

    Tạo liên kết thư mục (symlink) từ B trỏ về A.
        A - thư mục để quản lý code/git
        B - thư mục để build/test trên MetaEditor
        
    Bước 1: Xoá thư mục project trong MetaEditor (B)
        Ví dụ:
        C:\Users\...\AppData\Roaming\MetaQuotes\Terminal\XXXX\MQL5\Experts\MyBot

    Bước 2: Mở CMD với quyền Administrator
        Start → gõ cmd → Run as Administrator
        
    Bước 3: Tạo symbolic link
        mklink /D "C:\...\MQL5\Experts\MyBot" "D:\Code\MyBot"

        Trong đó:
        Đường đầu → thư mục B (MetaEditor)
        Đường sau → thư mục A (repo Git của bạn)