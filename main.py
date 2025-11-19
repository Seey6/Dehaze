import cv2
import numpy as np
import matplotlib.pyplot as plt
import time

def custom_min_filter_pure(image, kernel_size=15):
    """
    纯算法实现的最小值滤波 (Sliding Window 方式)。
    模拟硬件中的局部窗口扫描过程。
    """
    # 获取图像尺寸
    h, w = image.shape
    pad = kernel_size // 2
    
    # 填充边界 (Hardware Note: 硬件通常使用边缘复制或镜像，或者在控制逻辑中处理边界)
    padded_image = np.pad(image, pad, mode='edge')
    
    output = np.zeros_like(image)
    
    # --- Hardware Optimization Note: 窗口扫描与行缓存 ---
    # 在软件中，我们使用双重循环模拟“滑动窗口”。
    # 在硬件 (FPGA/ASIC) 中，不会把整张图读入内存。
    # 而是使用 "Line Buffers" (行缓存) 存储 kernel_size - 1 行像素。
    # 随着像素流 (Pixel Stream) 的输入，实时构建 15x15 的窗口。
    # 引用: [cite: 91, 217]
    
    for i in range(h):
        for j in range(w):
            # 提取当前窗口 (Region of Interest)
            # 对应论文中的 Omega(x) [cite: 120]
            window = padded_image[i:i+kernel_size, j:j+kernel_size]
            
            # 计算窗口内的最小值
            # --- Hardware Optimization Note: 滤波器分解 ---
            # 论文中提到，直接实现 15x15 的比较器非常消耗资源。
            # 硬件方案是将 15x15 分解为级联的 3x3 最小值滤波器。
            # Stage 2 & 3: 先做 3x3 滤波存入 buffer。
            # Stage 4 & 5: 在 buffer 基础上再做 3x3，逐级扩大感受野。
            # 引用: [cite: 213, 219, 226]
            min_val = np.min(window)
            output[i, j] = min_val
            
    return output

def dehaze_hardware_prototype(img_path):
    # 读取图像 (归一化到 0-1 浮点数)
    # --- Hardware Optimization Note: 定点数 ---
    # 硬件实现中通常不使用浮点数，而是使用定点数 (Fixed-point)。
    # 论文中将饱和度值缩放到 12-bit (0-4095) 进行处理以保持精度。
    # 引用: 
    H = cv2.imread(img_path).astype(np.float32) / 255.0
    if H is None:
        print("Error: Image not found.")
        return
    
    h, w, _ = H.shape

    # =========================================================
    # Stage 1: 预处理与下采样
    # =========================================================
    # --- Hardware Optimization Note: 下采样 ---
    # 论文为了减少行缓存 (Line Buffer) 的大小和计算量，
    # 首先将输入图像下采样 2 倍 (Downsample by 2)。
    # 这将 Line Buffers 的需求减半 (w/2)。
    # 引用: 
    H_ds = cv2.resize(H, (w // 2, h // 2))
    
    # =========================================================
    # Stage 2-6 (ALE Module): 大气光估计
    # =========================================================
    print("正在进行纯算法最小值滤波 (可能较慢)...")
    start_time = time.time()
    
    # 计算每个像素RGB中的最小值 (Min3)
    # 对应论文 Stage 6 中的 Min3 操作 [cite: 221]
    min_channel_ds = np.min(H_ds, axis=2)
    
    # 对下采样后的图进行 15x15 最小值滤波
    # 对应论文 Fig. 3 中的操作 [cite: 208]
    dark_channel_ds = custom_min_filter_pure(min_channel_ds, kernel_size=15)
    
    print(f"滤波耗时: {time.time() - start_time:.4f}s")

    # 估计大气光 A
    # --- Hardware Optimization Note: 避免排序 ---
    # 传统的 DCP 算法需要对暗通道像素进行排序取前 0.1%。
    # 论文为了硬件加速，去掉了排序过程 [cite: 203, 209]。
    # 硬件实现是在像素流过时，动态比较并记录当前遇到的最大值 (Run-time max tracking)。
    # 引用: [cite: 222]
    flat_dark = dark_channel_ds.flatten()
    flat_img_ds = H_ds.reshape(-1, 3)
    
    max_idx = np.argmax(flat_dark) # 硬件中通过比较器锁存最大值的地址/数值
    A = flat_img_ds[max_idx]
    
    # 论文假设 A 的最小值不小于 100 (在 0-255 尺度下)，即 ~0.39
    # 引用: [cite: 222]
    A = np.maximum(A, 100/255.0)
    print(f"Estimated Atmospheric Light A: {A}")

    # =========================================================
    # Stage 2 (Main Pipeline): 图像归一化
    # =========================================================
    # --- Hardware Optimization Note: 查找表代替除法 ---
    # 硬件中做除法 (H/A) 很昂贵。
    # 论文使用了查找表 (LUT) 来存储 1/A 的值，然后将除法转换为乘法 (H * (1/A))。
    # 引用: [cite: 195, 335]
    Hn = H / A
    
    # =========================================================
    # Stage 3: 饱和度估计 (Saturation Estimation)
    # =========================================================
    # 计算强度 K (均值) 和 最小值
    K_Hn = np.mean(Hn, axis=2)
    # 避免除以 0
    K_Hn = np.maximum(K_Hn, 1e-6)
    min_Hn = np.min(Hn, axis=2)
    
    # 公式 (9): S_H = 1 - min/K
    # --- Hardware Optimization Note: 查找表 ---
    # 这里同样计算 1/K 使用 LUT，然后用乘法代替除法。
    # 引用:
    S_H = 1 - (min_Hn / K_Hn)
    S_H = np.clip(S_H, 0, 1)
    
    # =========================================================
    # Stage 4: 对比度拉伸 (Contrast Stretching)
    # =========================================================
    # 预测去雾后的饱和度 S_D'
    # 公式 (15): S_D = S_H * (2.0 - S_H)
    # --- Hardware Optimization Note: 硬件友好的公式 ---
    # 论文特意选择了这个二次函数，因为它只需要加法和乘法，
    # 不需要复杂的指数运算 (Exponential functions)，节省资源。
    # 引用: [cite: 279, 284]
    S_D = S_H * (2.0 - S_H)
    S_D = np.maximum(S_D, 1e-6) # 保护

    # =========================================================
    # Stage 5-6: 透射率计算 (Transmission Calculation)
    # =========================================================
    # 公式 (14) 变体
    psi = 1.25 # 论文固定的系数 [cite: 427]
    
    # t = 1 - psi * K_Hn * (1 - S_H / S_D)
    # 注意：S_H / S_D 在硬件中可能也通过 LUT 或 迭代除法器 实现
    term = 1 - (S_H / S_D)
    t = 1 - psi * K_Hn * term
    
    # 限制 t 的范围
    t = np.clip(t, 0.1, 1.0)

    # =========================================================
    # Stage 7: 场景恢复 (Scene Restoration)
    # =========================================================
    # 公式 (2): D = (H - A)/t + A
    # --- Hardware Optimization Note: 最后的流水线级 ---
    # 计算 1/t 使用 LUT [cite: 416]。
    # 这是一个逐像素操作，只需当前像素的 H, t 和全局的 A。
    t_rep = np.repeat(t[:, :, np.newaxis], 3, axis=2)
    D = (H - A) / t_rep + A
    
    D = np.clip(D, 0, 1)
    
    return H, D, t

# ---------------------------------------------------------
# 使用示例
# ---------------------------------------------------------
if __name__ == "__main__":
    # 请替换为你的本地图片路径
    img_path = "haze.jpg"
    H, D, t_map = dehaze_hardware_prototype(img_path)
    
    if H is not None:
        cv2.imshow("Hazy Input", H)
        cv2.imshow("Dehazed Output", D)
        cv2.imshow("Transmission", t_map)
        cv2.waitKey(0)
        cv2.destroyAllWindows()
    