using UnityEngine;

namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// 附加的后处理Pass
    public class KawaseBlurRenderPass : ScriptableRenderPass
    {
        //标签名，用于续帧调试器中显示缓冲区名称
        const string CommandBufferTag = "KawaseBlurRenderPass Pass";
        // 用于后处理的材质
        public Material m_Material;
        // 属性参数组件
        KawaseBlur m_KawaseBlur;

        // 颜色渲染标识符
        RenderTargetIdentifier m_ColorAttachment;
        // 临时的渲染目标
        RenderTargetHandle m_TemporaryColorTexture01;
        RenderTargetHandle m_TemporaryColorTexture02;

        public KawaseBlurRenderPass()
        {
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture1");
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture2");
        }

        // 设置渲染参数
        public void Setup(RenderTargetIdentifier _ColorAttachment, Material Material)
        {
            this.m_ColorAttachment = _ColorAttachment;
            m_Material = Material;
        }

        /// <summary>
        /// URP会自动调用该执行方法
        /// </summary>
        /// <param name="context"></param>
        /// <param name="renderingData"></param>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            m_KawaseBlur = stack.GetComponent<KawaseBlur>();
            // 从命令缓冲区池中获取一个带标签的渲染命令，该标签名可以在后续帧调试器中见到
            var cmd = CommandBufferPool.Get(CommandBufferTag);
            // 调用渲染函数
            Render(cmd, ref renderingData);
            // 释放临时RT
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture02.id);
            // 执行命令缓冲区
            context.ExecuteCommandBuffer(cmd);
        }

        // 渲染
        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // VolumeComponent是否开启，且非Scene视图摄像机
            if (m_KawaseBlur.IsActive()&&!renderingData.cameraData.isSceneViewCamera)
            {
                // 写入参数
                m_Material.SetFloat("_BlurSize", m_KawaseBlur.blurSize.value);
                // 获取目标相机的描述信息
                RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;

                // 设置深度缓冲区
                opaqueDesc.depthBufferBits = 0;

                // 降采样
                opaqueDesc.width /= m_KawaseBlur.downSample.value;
                opaqueDesc.height /= m_KawaseBlur.downSample.value;
                // 通过目标相机的渲染信息创建临时缓冲区
                cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, opaqueDesc);
                cmd.GetTemporaryRT(m_TemporaryColorTexture02.id, opaqueDesc);
                // 通过材质，将计算结果存入临时缓冲区
                cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier());

                // 循环开启
				for (int i = 0; i < m_KawaseBlur.iteration.value; i++)
				{
                    cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_TemporaryColorTexture02.Identifier(), m_Material, 0);
                    var tempId = m_TemporaryColorTexture01;
                    m_TemporaryColorTexture01 = m_TemporaryColorTexture02;
                    m_TemporaryColorTexture02 = tempId;
				}
                // 再从临时缓冲区存入主纹理
                cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_ColorAttachment);
            }
        }
    }
}