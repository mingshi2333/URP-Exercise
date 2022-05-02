using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.Universal
{
    public class GaussianBlurRenderPass : ScriptableRenderPass
    {
        const string CommandBufferTag = "GaussianBlurRenderPass Pass";
        public Material m_Material;
        GaussianBlur m_GaussianBlur;

        RenderTargetIdentifier m_ColorAttachment;
        RenderTargetHandle m_TemporaryColorTexture01;
        RenderTargetHandle m_TemporaryColorTexture02;
        public GaussianBlurRenderPass()
        {
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture1");
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture2");
        }
        public void Setup(RenderTargetIdentifier _ColorAttachment, Material Material)
        {
            this.m_ColorAttachment = _ColorAttachment;
            m_Material = Material;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            m_GaussianBlur = stack.GetComponent<GaussianBlur>();
            var cmd = CommandBufferPool.Get(CommandBufferTag);

            Render(cmd,ref renderingData);
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture02.id);
            context.ExecuteCommandBuffer(cmd);
        }
        void Render(CommandBuffer cmd,ref RenderingData renderingData)
        {
            if(m_GaussianBlur.IsActive()&&!renderingData.cameraData.isSceneViewCamera)
            {
                m_Material.SetFloat("_BlurSize",m_GaussianBlur.blurSize.value);
                RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
                opaqueDesc.depthBufferBits = 0;
                opaqueDesc.width /= m_GaussianBlur.downSample.value;
                opaqueDesc.height /= m_GaussianBlur.downSample.value;
                cmd.GetTemporaryRT(m_TemporaryColorTexture01.id,opaqueDesc);
                cmd.GetTemporaryRT(m_TemporaryColorTexture02.id,opaqueDesc);
                cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier());

                for(int i =0;i<m_GaussianBlur.iteration.value;i++)
                {
                    cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_TemporaryColorTexture02.Identifier(), m_Material, 0);
                

                    // var tempId = m_TemporaryColorTexture01;
                    // m_TemporaryColorTexture01 = m_TemporaryColorTexture02;
                    // m_TemporaryColorTexture02 = tempId;
                    cmd.Blit(m_TemporaryColorTexture02.Identifier(), m_TemporaryColorTexture01.Identifier(), m_Material, 1);
                    
                }
                cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_ColorAttachment);


            }
        }
    }
}
