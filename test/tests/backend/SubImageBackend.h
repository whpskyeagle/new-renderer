/****************************************************************************
 Copyright (c) 2018 Xiamen Yaji Software Co., Ltd.

 http://www.cocos2d-x.org

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/

#pragma once

#include "math/mat4.h"
#include "TestBase.h"
#include "backend/backend.h"

class SubImageBackend : public TestBaseI
{
public:
    DEFINE_CREATE_METHOD(SubImageBackend)
    SubImageBackend();
    ~SubImageBackend();
    virtual void tick(float dt) override;

private:
    cocos2d::backend::Buffer* _vertexBuffer = nullptr;
    cocos2d::backend::RenderPipeline* _renderPipeline = nullptr;
    cocos2d::backend::CommandBuffer* _commandBuffer = nullptr;
    cocos2d::backend::Texture* _texture = nullptr;
    cocos2d::backend::BindGroup _bindGroup;
    cocos2d::backend::RenderPassDescriptor _renderPassDescriptor;

    cocos2d::Mat4 _transform0;

    uint8_t* _data;
    size_t _dataSize;
    size_t _updatePixelIndex;
};



