using System.Collections;
using System.Collections.Generic;
using UnityEngine;
namespace UnityEngine.Rendering.Universal
{
    public class GaussianBlurRenderFeature : ScriptableRendererFeature
    {
        // Start is called before the first frame update

        public Shader shader;
        GaussianBlurRenderPass postPass;
        public RenderPassEvent renderPassEvent;

        Material _Material = null;

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (shader == null)
                return;
            // 创建材质
            if (_Material == null)
                _Material = CoreUtils.CreateEngineMaterial(shader);
            // 获取当前渲染相机的目标颜色，也就是主纹理
            var cameraColorTarget = renderer.cameraColorTarget;
            // 设置调用后处理Pass
            postPass.Setup(cameraColorTarget, _Material);
            // 添加该Pass到渲染管线中
            renderer.EnqueuePass(postPass);
        }
        public override void Create()
        {
            postPass = new GaussianBlurRenderPass();
            postPass.renderPassEvent = renderPassEvent;
            
        }

    }
}