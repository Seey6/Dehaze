import cv2
import numpy as np

img_path = './hazy.jpg'
H = cv2.imread(img_path).astype(np.float32) / 255.0

h, w, _ = H.shape

Hstream = H.reshape(-1, 3)  # Pixel Stream: 按行展开的像素流

def calcA(pixel: np.ndarray) -> np.float32:
    """
    硬件中的全局最大值计算。
    """
    # --- Hardware Optimization Note: 并行比较器 ---
    # 论文中提到，硬件实现中使用并行比较器 (Parallel Comparators)
    # 来同时处理多个像素，从而加快最大值计算速度。
    # 引用: [cite: 85, 190]
    
    max_val = np.max(pixel, axis=0)
    return max_val