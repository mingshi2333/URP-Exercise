using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEngine.Rendering.Universal
{
    public class BloomRendererPass : ScriptableRenderPass
    {
        const string CommandBufferTag = "BloomRenderPass Pass";
        public Material m_Material;
        Bloom m_Bloom;
        RenderTargetIdentifier m_ColorAttachment;
        
        RenderTargetHandle m_TemporaryColorTexture01;
        RenderTargetHandle m_TemporaryColorTexture02;
        RenderTargetHandle m_TemporaryColorTexture03;
        Texture m_Texture;
        public BloomRendererPass()
        {
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture1");
            m_TemporaryColorTexture02.Init("_TemporaryColorTexture2");
            m_TemporaryColorTexture03.Init("_TemporaryColorTexture3");
        }
        public void Setup(RenderTargetIdentifier _ColorAttachment, Material Material)
        {
            this.m_ColorAttachment = _ColorAttachment;
            m_Material = Material;
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            m_Bloom = stack.GetComponent<Bloom>();
            var cmd = CommandBufferPool.Get(CommandBufferTag);
            Render(cmd,ref renderingData);
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture02.id);
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture03.id);
            context.ExecuteCommandBuffer(cmd);
        }
        void Render(CommandBuffer cmd,ref RenderingData renderingData)
        {
            m_Material.SetFloat("_BlurSize",m_Bloom.blurSize.value);
            m_Material.SetFloat("_LuminanceThreshold",m_Bloom.luminanceThreshold.value);
            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(m_TemporaryColorTexture03.id,opaqueDesc);
            cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture03.Identifier());


             opaqueDesc.width /= m_Bloom.downSample.value;
             opaqueDesc.height /= m_Bloom.downSample.value;
            cmd.GetTemporaryRT(m_TemporaryColorTexture01.id,opaqueDesc);
            cmd.GetTemporaryRT(m_TemporaryColorTexture02.id,opaqueDesc);
            
            cmd.Blit(m_TemporaryColorTexture03.Identifier(),m_TemporaryColorTexture01.Identifier(),m_Material,0);
            for(int i=0;i<m_Bloom.iteration.value;i++)
            {
                cmd.Blit(m_TemporaryColorTexture01.Identifier(),m_TemporaryColorTexture02.Identifier(),m_Material,1);
                cmd.Blit(m_TemporaryColorTexture02.Identifier(),m_TemporaryColorTexture01.Identifier(),m_Material,2);               

            }
            cmd.SetGlobalTexture("_BloomTex",m_TemporaryColorTexture01.Identifier());

            cmd.Blit(m_TemporaryColorTexture03.Identifier(), m_ColorAttachment,m_Material,3);
            //cmd.Blit(m_ColorAttachment,m_Texture);
            //m_Material.SetTexture("_Bloom",m_Texture);
            // //cmd.Blit(m_ColorAttachmentsrc,m_ColorAttachment,m_Material,3);
            //cmd.Blit(m_TemporaryColorTexture03.Identifier(),m_ColorAttachment,m_Material,3);
            //cmd.Blit(m_ColorAttachment,m_ColorAttachment);

        }
    }
}
