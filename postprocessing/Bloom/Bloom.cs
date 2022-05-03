using System;

// 通用渲染管线程序集
namespace UnityEngine.Rendering.Universal
{
    // 实例化类     添加到Volume组件菜单中
    [Serializable, VolumeComponentMenu("Addition-Post-processing/Bloom")]
    // 继承VolumeComponent组件和IPostProcessComponent接口，用以继承Volume框架
    public class Bloom : VolumeComponent, IPostProcessComponent
    {
        // 在框架下的属性与Unity常规属性不一样，例如 Int 由 ClampedIntParameter 取代。dddd
        public ClampedIntParameter iteration = new ClampedIntParameter(1, 1, 7);
        public ClampedIntParameter downSample = new ClampedIntParameter(1, 1, 3);
        public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0, 9);
        public ClampedFloatParameter luminanceThreshold = new ClampedFloatParameter(0f,0,9);

        //public ColorParameter tint = new ColorParameter(Color.white, false, false, true);

        // 实现接口
        public bool IsActive()
        {
            return active;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}