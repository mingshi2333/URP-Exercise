using System;

// 通用渲染管线程序集
namespace UnityEngine.Rendering.Universal
{
    // 实例化类     添加到Volume组件菜单中
    [Serializable, VolumeComponentMenu("Addition-Post-processing/SSAO")]
    // 继承VolumeComponent组件和IPostProcessComponent接口，用以继承Volume框架
    public class SSAO : VolumeComponent, IPostProcessComponent
    {
        // 在框架下的属性与Unity常规属性不一样，例如 Int 由 ClampedIntParameter 取代。dddd
        public ClampedIntParameter contrast  = new ClampedIntParameter(1, 1, 7);
        public ClampedIntParameter atten  = new ClampedIntParameter(1, 1, 3);
        public ClampedFloatParameter sampleRadius  = new ClampedFloatParameter(0.1f, 0, 1);
        public ClampedIntParameter sampleCount   = new ClampedIntParameter(4, 0, 9);
        
        public ClampedIntParameter iteration = new ClampedIntParameter(1, 1, 7);
        public ClampedIntParameter downSample = new ClampedIntParameter(1, 1, 3);
        public ClampedFloatParameter blurSize = new ClampedFloatParameter(1f, 0, 9);
        public BoolParameter AO = new BoolParameter(true,false);


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