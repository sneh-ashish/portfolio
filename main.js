/**
 * RAYHAN ADITYA — 3D SCROLL ANIMATION PORTFOLIO
 * High-performance Three.js Engine & Interactive Experience
 */

document.addEventListener('DOMContentLoaded', () => {

    /* ==========================================================================
       1. WEB AUDIO API SYNTHESIZER (Micro-interactions)
       ========================================================================== */
    let audioCtx = null;
    let soundEnabled = true;
    const soundToggle = document.getElementById('soundToggle');
    const soundWaves = document.getElementById('soundWaves');

    const initAudio = () => {
        if (!audioCtx) {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            if (AudioContext) audioCtx = new AudioContext();
        }
        if (audioCtx && audioCtx.state === 'suspended') {
            audioCtx.resume();
        }
    };

    const playTone = (freq = 440, type = 'sine', duration = 0.08, gainVal = 0.04) => {
        if (!soundEnabled) return;
        try {
            initAudio();
            if (!audioCtx) return;
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.type = type;
            osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
            gain.gain.setValueAtTime(gainVal, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + duration);
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.start();
            osc.stop(audioCtx.currentTime + duration);
        } catch (e) {
            // Audio context not allowed or failed silently
        }
    };

    if (soundToggle) {
        soundToggle.addEventListener('click', () => {
            soundEnabled = !soundEnabled;
            if (soundEnabled) {
                soundWaves.style.display = 'block';
                soundToggle.style.color = '#ff1f38';
                soundToggle.style.borderColor = '#ff1f38';
                playTone(660, 'sine', 0.1, 0.08);
            } else {
                soundWaves.style.display = 'none';
                soundToggle.style.color = '#666';
                soundToggle.style.borderColor = 'rgba(255, 255, 255, 0.15)';
            }
        });
    }

    /* ==========================================================================
       2. CUSTOM CURSOR
       ========================================================================== */
    const cursor = document.getElementById('cursor');
    const cursorDot = document.getElementById('cursor-dot');
    let mouseX = window.innerWidth / 2;
    let mouseY = window.innerHeight / 2;
    let cursorX = mouseX;
    let cursorY = mouseY;

    window.addEventListener('mousemove', (e) => {
        mouseX = e.clientX;
        mouseY = e.clientY;
        if (cursorDot) {
            cursorDot.style.left = `${mouseX}px`;
            cursorDot.style.top = `${mouseY}px`;
        }
    });

    const updateCursor = () => {
        if (cursor) {
            cursorX += (mouseX - cursorX) * 0.18;
            cursorY += (mouseY - cursorY) * 0.18;
            cursor.style.left = `${cursorX}px`;
            cursor.style.top = `${cursorY}px`;
        }
        requestAnimationFrame(updateCursor);
    };
    updateCursor();

    const hoverTargets = document.querySelectorAll('a, button, .project-card, .contact-info-item, .skill-tag, .quote-card');
    hoverTargets.forEach((el) => {
        el.addEventListener('mouseenter', () => {
            cursor?.classList.add('cursor-hover');
            playTone(880, 'triangle', 0.04, 0.02);
        });
        el.addEventListener('mouseleave', () => {
            cursor?.classList.remove('cursor-hover');
        });
    });

    /* ==========================================================================
       3. THREE.JS 3D SCENE & SCROLL ANIMATION SYSTEM
       ========================================================================== */
    const canvas = document.getElementById('webgl-canvas');
    if (typeof THREE !== 'undefined' && canvas) {
        // Scene setup
        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(50, window.innerWidth / window.innerHeight, 0.1, 1000);
        camera.position.set(0, 0, 7);

        const renderer = new THREE.WebGLRenderer({
            canvas: canvas,
            antialias: true,
            alpha: true,
            powerPreference: 'high-performance'
        });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

        // Dynamic Lighting
        const ambientLight = new THREE.AmbientLight(0x180508, 1.8);
        scene.add(ambientLight);

        const redPointLight = new THREE.PointLight(0xff1f38, 4, 30);
        redPointLight.position.set(3, 2, 4);
        scene.add(redPointLight);

        const rimLight = new THREE.PointLight(0xd80027, 3, 25);
        rimLight.position.set(-4, -2, 3);
        scene.add(rimLight);

        const directionalLight = new THREE.DirectionalLight(0xffffff, 1.2);
        directionalLight.position.set(2, 6, 5);
        scene.add(directionalLight);

        // Core 3D Cyber Artifact Group
        const coreGroup = new THREE.Group();
        scene.add(coreGroup);

        // 1. Geometric Outer Shell: High-Tech Wireframe Dodecahedron
        const shellGeo = new THREE.IcosahedronGeometry(1.6, 1);
        const shellMat = new THREE.MeshStandardMaterial({
            color: 0x140204,
            wireframe: true,
            roughness: 0.2,
            metalness: 0.9,
            emissive: 0x800a12,
            emissiveIntensity: 0.45,
            transparent: true,
            opacity: 0.6
        });
        const shellMesh = new THREE.Mesh(shellGeo, shellMat);
        coreGroup.add(shellMesh);

        // 2. Inner Glowing Crimson Crystal
        const innerGeo = new THREE.OctahedronGeometry(0.9, 0);
        const innerMat = new THREE.MeshPhysicalMaterial({
            color: 0xff0f38,
            emissive: 0xff1f38,
            emissiveIntensity: 0.7,
            roughness: 0.1,
            metalness: 0.3,
            transmission: 0.6,
            thickness: 1.2,
            transparent: true,
            opacity: 0.6
        });
        const innerCore = new THREE.Mesh(innerGeo, innerMat);
        coreGroup.add(innerCore);

        // 3. Orbital Gimbal Rings
        const ringMat1 = new THREE.MeshStandardMaterial({
            color: 0xff2a4b,
            emissive: 0xaa0e20,
            metalness: 0.8,
            roughness: 0.3,
            transparent: true,
            opacity: 0.6
        });
        const ringMat2 = new THREE.MeshStandardMaterial({
            color: 0x66000c,
            metalness: 0.9,
            roughness: 0.2,
            transparent: true,
            opacity: 0.6
        });

        const ring1 = new THREE.Mesh(new THREE.TorusGeometry(2.3, 0.025, 16, 100), ringMat1);
        const ring2 = new THREE.Mesh(new THREE.TorusGeometry(2.6, 0.02, 16, 100), ringMat2);
        const ring3 = new THREE.Mesh(new THREE.TorusGeometry(2.9, 0.018, 16, 100), ringMat1);

        ring1.rotation.x = Math.PI / 3;
        ring2.rotation.y = Math.PI / 4;
        ring3.rotation.z = Math.PI / 6;

        coreGroup.add(ring1);
        coreGroup.add(ring2);
        coreGroup.add(ring3);

        // 4. Floating Satellites (Tiny Geometric Polyhedrons)
        const satellites = [];
        const satMat = new THREE.MeshStandardMaterial({
            color: 0xff1f38,
            metalness: 0.9,
            roughness: 0.2,
            transparent: true,
            opacity: 0.6
        });

        for (let i = 0; i < 6; i++) {
            const satGeo = new THREE.TetrahedronGeometry(0.12, 0);
            const satMesh = new THREE.Mesh(satGeo, satMat);
            satellites.push({
                mesh: satMesh,
                radius: 3.2 + Math.random() * 0.8,
                speed: (0.8 + Math.random() * 0.6) * (i % 2 === 0 ? 1 : -1),
                angle: (i / 6) * Math.PI * 2,
                tilt: Math.random() * Math.PI
            });
            coreGroup.add(satMesh);
        }

        // 5. 3D Particle Nebula Field (1,200 particles)
        const particleCount = 1200;
        const particleGeo = new THREE.BufferGeometry();
        const positions = new Float32Array(particleCount * 3);
        const colors = new Float32Array(particleCount * 3);

        const colorCrimson = new THREE.Color(0xff1f38);
        const colorRuby = new THREE.Color(0x990014);
        const colorAmber = new THREE.Color(0xff6b35);
        const colorDim = new THREE.Color(0x330008);

        for (let i = 0; i < particleCount; i++) {
            positions[i * 3] = (Math.random() - 0.5) * 28;
            positions[i * 3 + 1] = (Math.random() - 0.5) * 28;
            positions[i * 3 + 2] = (Math.random() - 0.5) * 25;

            const rand = Math.random();
            const pickedColor = rand < 0.4 ? colorCrimson : (rand < 0.7 ? colorRuby : (rand < 0.85 ? colorAmber : colorDim));
            colors[i * 3] = pickedColor.r;
            colors[i * 3 + 1] = pickedColor.g;
            colors[i * 3 + 2] = pickedColor.b;
        }

        particleGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        particleGeo.setAttribute('color', new THREE.BufferAttribute(colors, 3));

        // Create soft round circle texture for particles
        const createParticleTexture = () => {
            const pCanvas = document.createElement('canvas');
            pCanvas.width = 32;
            pCanvas.height = 32;
            const ctx = pCanvas.getContext('2d');
            const grad = ctx.createRadialGradient(16, 16, 0, 16, 16, 16);
            grad.addColorStop(0, 'rgba(255, 255, 255, 1)');
            grad.addColorStop(0.3, 'rgba(255, 40, 60, 0.8)');
            grad.addColorStop(0.8, 'rgba(220, 10, 30, 0.2)');
            grad.addColorStop(1, 'rgba(0, 0, 0, 0)');
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, 32, 32);
            return new THREE.CanvasTexture(pCanvas);
        };

        const particleMat = new THREE.PointsMaterial({
            size: 0.14,
            map: createParticleTexture(),
            vertexColors: true,
            transparent: true,
            opacity: 0.85,
            blending: THREE.AdditiveBlending,
            depthWrite: false
        });

        const particleSystem = new THREE.Points(particleGeo, particleMat);
        scene.add(particleSystem);

        // Scroll Tracking & Camera Trajectory
        let scrollY = 0;
        let lastScrollY = 0;
        let scrollVelocity = 0;
        let targetProgress = 0;
        let currentProgress = 0;

        window.addEventListener('scroll', () => {
            scrollY = window.scrollY;
            const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
            targetProgress = maxScroll > 0 ? scrollY / maxScroll : 0;
            scrollVelocity = (scrollY - lastScrollY);
            lastScrollY = scrollY;
        });

        // Mouse Parallax values
        let normMouseX = 0;
        let normMouseY = 0;
        window.addEventListener('mousemove', (e) => {
            normMouseX = (e.clientX / window.innerWidth) * 2 - 1;
            normMouseY = -(e.clientY / window.innerHeight) * 2 + 1;
        });

        // Responsive Resizing
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        });

        // Main Animation Clock & Render Loop
        const clock = new THREE.Clock();

        const animate = () => {
            requestAnimationFrame(animate);
            const delta = clock.getDelta();
            const elapsedTime = clock.getElapsedTime();

            // Smooth Scroll Progress Lerp
            currentProgress += (targetProgress - currentProgress) * 0.06;

            // 3D Object continuous self-rotation
            shellMesh.rotation.x = elapsedTime * 0.25;
            shellMesh.rotation.y = elapsedTime * 0.35;
            innerCore.rotation.y = -elapsedTime * 0.5;
            innerCore.rotation.z = elapsedTime * 0.3;

            // Orbital rings rotation
            ring1.rotation.z = elapsedTime * 0.4;
            ring2.rotation.x = elapsedTime * 0.3;
            ring3.rotation.y = elapsedTime * 0.25;

            // Satellites orbiting
            satellites.forEach((sat) => {
                sat.angle += sat.speed * delta;
                sat.mesh.position.x = Math.cos(sat.angle) * sat.radius;
                sat.mesh.position.y = Math.sin(sat.angle) * Math.cos(sat.tilt) * sat.radius;
                sat.mesh.position.z = Math.sin(sat.angle) * Math.sin(sat.tilt) * (sat.radius * 0.6);
                sat.mesh.rotation.x += 0.02;
                sat.mesh.rotation.y += 0.03;
            });

            // Particles rotation & warp rush with scroll velocity
            particleSystem.rotation.y = elapsedTime * 0.04;
            particleSystem.rotation.x = Math.sin(elapsedTime * 0.02) * 0.1;

            // SCROLL-DRIVEN 3D CAMERA & CORE TRANSFORMS:
            // Section 0 (Hero): progress 0.0 - 0.25 -> Core centered-right, bold & prominent
            // Section 1 (Projects): progress 0.25 - 0.55 -> Core shifts right & deepens, rings expand
            // Section 2 (Process): progress 0.55 - 0.80 -> Core shifts left, aligns vertically
            // Section 3 (Contact): progress 0.80 - 1.0 -> Core shifts bottom-right, warm glow
            let targetX = 0;
            let targetY = 0;
            let targetZ = 0;
            let targetScale = 1;
            let targetCamX = 0;
            let targetCamY = 0;

            if (currentProgress < 0.3) {
                const t = currentProgress / 0.3;
                targetX = 1.6 * (1 - t) + 2.8 * t;
                targetY = 0.2 * (1 - t) + (-0.4) * t;
                targetZ = 0 * (1 - t) + (-1.5) * t;
                targetScale = 1.05 * (1 - t) + 0.9 * t;
                targetCamX = 0;
                targetCamY = 0;
            } else if (currentProgress < 0.65) {
                const t = (currentProgress - 0.3) / 0.35;
                targetX = 2.8 * (1 - t) + (-2.6) * t;
                targetY = -0.4 * (1 - t) + 0.3 * t;
                targetZ = -1.5 * (1 - t) + (-0.5) * t;
                targetScale = 0.9 * (1 - t) + 1.1 * t;
                targetCamX = 0.3 * t;
                targetCamY = -0.2 * t;
            } else {
                const t = (currentProgress - 0.65) / 0.35;
                targetX = -2.6 * (1 - t) + 2.2 * t;
                targetY = 0.3 * (1 - t) + (-1.2) * t;
                targetZ = -0.5 * (1 - t) + 0.4 * t;
                targetScale = 1.1 * (1 - t) + 0.95 * t;
                targetCamX = 0.3 * (1 - t) + 0;
                targetCamY = -0.2 * (1 - t) + (-0.3) * t;
            }

            // Smooth position lerp with gentle float
            const floatOffset = Math.sin(elapsedTime * 1.5) * 0.12;
            coreGroup.position.x += (targetX - coreGroup.position.x) * 0.08;
            coreGroup.position.y += (targetY + floatOffset - coreGroup.position.y) * 0.08;
            coreGroup.position.z += (targetZ - coreGroup.position.z) * 0.08;

            coreGroup.scale.x += (targetScale - coreGroup.scale.x) * 0.08;
            coreGroup.scale.y += (targetScale - coreGroup.scale.y) * 0.08;
            coreGroup.scale.z += (targetScale - coreGroup.scale.z) * 0.08;

            // Mouse parallax influence on camera
            const mouseCamX = targetCamX + normMouseX * 0.4;
            const mouseCamY = targetCamY + normMouseY * 0.3;
            camera.position.x += (mouseCamX - camera.position.x) * 0.05;
            camera.position.y += (mouseCamY - camera.position.y) * 0.05;
            camera.lookAt(coreGroup.position.x * 0.2, coreGroup.position.y * 0.2, 0);

            // Dynamic Point light following cursor
            redPointLight.position.x = normMouseX * 5 + 2;
            redPointLight.position.y = normMouseY * 4 + 1;

            renderer.render(scene, camera);
        };

        animate();
    }

    /* ==========================================================================
       4. HERO PARALLAX & DYNAMIC SCROLL EXIT ANIMATION
       ========================================================================== */
    const heroBgText = document.getElementById('heroBgText');
    const heroPortrait = document.getElementById('heroPortrait');
    let mouseParallaxX = 0;
    let mouseParallaxY = 0;

    const updateHeroExit = () => {
        const scrollY = window.scrollY;
        // Gracefully exits out of the frame as the user scrolls past hero (320px)
        const exitThreshold = 320;
        const exitProgress = Math.min(Math.max(scrollY / exitThreshold, 0), 1);

        if (heroBgText) {
            if (scrollY <= 10) {
                // At the top of the page: 100% visible, perfectly centered!
                heroBgText.style.visibility = 'visible';
                heroBgText.style.opacity = '0.95';
                heroBgText.style.transform = `translate(${mouseParallaxX * -0.6}px, ${mouseParallaxY * -0.4}px)`;
            } else if (exitProgress >= 0.98) {
                // Completely out of the frame after scrolling past hero
                heroBgText.style.opacity = '0';
                heroBgText.style.visibility = 'hidden';
                heroBgText.style.transform = `translate(${mouseParallaxX * -0.6}px, -280px)`;
            } else {
                heroBgText.style.visibility = 'visible';
                const yExit = exitProgress * 280; // Smooth upward motion out of frame
                const opacity = Math.max(0, 0.95 * (1 - Math.pow(exitProgress, 1.25)));
                const scale = 1 + exitProgress * 0.08;

                heroBgText.style.opacity = opacity.toFixed(3);
                heroBgText.style.transform = `translate(${mouseParallaxX * -0.6}px, ${(mouseParallaxY * -0.4) - yExit}px) scale(${scale})`;
            }
        }

        if (heroPortrait) {
            heroPortrait.style.transform = `translate(${mouseParallaxX * 0.4}px, ${mouseParallaxY * 0.3}px) scale(1.01)`;
        }
    };

    window.addEventListener('mousemove', (e) => {
        mouseParallaxX = (e.clientX / window.innerWidth - 0.5) * 20;
        mouseParallaxY = (e.clientY / window.innerHeight - 0.5) * 15;
        updateHeroExit();
    });

    window.addEventListener('scroll', updateHeroExit, { passive: true });
    updateHeroExit();

    /* ==========================================================================
       5. 3D CARD PERSPECTIVE TILT (Projects Grid)
       ========================================================================== */
    const projectCards = document.querySelectorAll('.project-card');

    projectCards.forEach((card) => {
        const glare = card.querySelector('.project-glare');

        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;

            const centerX = rect.width / 2;
            const centerY = rect.height / 2;

            const rotateX = ((y - centerY) / centerY) * -12;
            const rotateY = ((x - centerX) / centerX) * 12;

            card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;

            if (glare) {
                glare.style.background = `radial-gradient(circle at ${x}px ${y}px, rgba(255, 255, 255, 0.18), transparent 60%)`;
            }
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
        });
    });

    /* ==========================================================================
       6. SERVICES CAROUSEL SLIDER (Contact Section)
       ========================================================================== */
    const carouselFrame = document.getElementById('carouselFrame');
    const carouselTrack = document.getElementById('carouselTrack');
    const carouselPrevBtn = document.getElementById('carouselPrevBtn');
    const carouselNextBtn = document.getElementById('carouselNextBtn');
    const carouselCounter = document.getElementById('carouselCounter');
    const carouselIndicators = document.querySelectorAll('.carousel-indicator');

    if (carouselFrame && carouselTrack) {
        const slides = carouselTrack.querySelectorAll('.carousel-slide');
        const totalSlides = slides.length;
        let currentSlide = 0;
        let autoSlideTimer = null;
        let isDragging = false;
        let startX = 0;
        let currentX = 0;

        const updateCarousel = (index) => {
            currentSlide = (index + totalSlides) % totalSlides;
            carouselTrack.style.transform = `translateX(-${currentSlide * 100}%)`;

            if (carouselCounter) {
                carouselCounter.textContent = `0${currentSlide + 1} / 0${totalSlides}`;
            }

            carouselIndicators.forEach((indicator, i) => {
                indicator.classList.toggle('active', i === currentSlide);
            });
        };

        const nextSlide = () => updateCarousel(currentSlide + 1);
        const prevSlide = () => updateCarousel(currentSlide - 1);

        const startAutoPlay = () => {
            stopAutoPlay();
            autoSlideTimer = setInterval(nextSlide, 4000);
        };

        const stopAutoPlay = () => {
            if (autoSlideTimer) {
                clearInterval(autoSlideTimer);
                autoSlideTimer = null;
            }
        };

        if (carouselNextBtn) {
            carouselNextBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                nextSlide();
                startAutoPlay();
            });
        }

        if (carouselPrevBtn) {
            carouselPrevBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                prevSlide();
                startAutoPlay();
            });
        }

        carouselIndicators.forEach((indicator) => {
            indicator.addEventListener('click', (e) => {
                e.stopPropagation();
                const targetIndex = parseInt(indicator.getAttribute('data-slide'), 10);
                if (!isNaN(targetIndex)) {
                    updateCarousel(targetIndex);
                    startAutoPlay();
                }
            });
        });

        // Pause on hover
        carouselFrame.addEventListener('mouseenter', stopAutoPlay);
        carouselFrame.addEventListener('mouseleave', startAutoPlay);

        // Keyboard arrows support when focused
        carouselFrame.addEventListener('keydown', (e) => {
            if (e.key === 'ArrowLeft') {
                prevSlide();
                startAutoPlay();
            } else if (e.key === 'ArrowRight') {
                nextSlide();
                startAutoPlay();
            }
        });

        // Touch & Drag gestures
        const onPointerDown = (e) => {
            isDragging = true;
            startX = e.clientX || (e.touches && e.touches[0].clientX) || 0;
            currentX = startX;
            stopAutoPlay();
        };

        const onPointerMove = (e) => {
            if (!isDragging) return;
            currentX = e.clientX || (e.touches && e.touches[0].clientX) || 0;
        };

        const onPointerUp = () => {
            if (!isDragging) return;
            isDragging = false;
            const diffX = currentX - startX;
            if (Math.abs(diffX) > 40) {
                if (diffX < 0) {
                    nextSlide();
                } else {
                    prevSlide();
                }
            }
            startAutoPlay();
        };

        carouselFrame.addEventListener('touchstart', onPointerDown, { passive: true });
        carouselFrame.addEventListener('touchmove', onPointerMove, { passive: true });
        carouselFrame.addEventListener('touchend', onPointerUp);

        carouselFrame.addEventListener('mousedown', onPointerDown);
        window.addEventListener('mousemove', onPointerMove);
        window.addEventListener('mouseup', onPointerUp);

        // Start autoplay
        startAutoPlay();
    }

    /* ==========================================================================
       7. ANIMATED NUMBER COUNTERS (On Scroll Into View)
       ========================================================================== */
    const statNumbers = document.querySelectorAll('.stat-number');
    let counted = false;

    const runCounters = () => {
        statNumbers.forEach((stat) => {
            const target = parseInt(stat.getAttribute('data-target'), 10);
            const duration = 1600;
            const startTime = performance.now();

            const updateCount = (currentTime) => {
                const elapsed = currentTime - startTime;
                const progress = Math.min(elapsed / duration, 1);
                // Ease-out cubic
                const easeOut = 1 - Math.pow(1 - progress, 3);
                const currentVal = Math.floor(easeOut * target);

                stat.textContent = `${currentVal}+`;

                if (progress < 1) {
                    requestAnimationFrame(updateCount);
                } else {
                    stat.textContent = `${target}+`;
                }
            };

            requestAnimationFrame(updateCount);
        });
    };

    const statsObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersectObserver && !counted) {
                counted = true;
                runCounters();
            } else if (entry.isIntersecting && !counted) {
                counted = true;
                runCounters();
            }
        });
    }, { threshold: 0.3 });

    const heroSection = document.getElementById('hero');
    if (heroSection) statsObserver.observe(heroSection);

    /* ==========================================================================
       8. WORK PROCESS TIMELINE HIGHLIGHT ON SCROLL
       ========================================================================== */
    const processSteps = document.querySelectorAll('.process-step');
    const stepObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                const node = entry.target.querySelector('.step-node');
                if (node) {
                    node.style.borderColor = '#ff1f38';
                    node.style.boxShadow = '0 0 22px rgba(229, 9, 20, 0.6)';
                }
            }
        });
    }, { threshold: 0.6 });

    processSteps.forEach((step) => stepObserver.observe(step));

    /* ==========================================================================
       9. 1-CLICK COPY WITH TOAST NOTIFICATION
       ========================================================================== */
    const copyActions = document.querySelectorAll('.copy-action');
    const toastNotice = document.getElementById('toastNotice');
    const toastMsg = document.getElementById('toastMsg');
    let toastTimeout = null;

    const showToast = (text) => {
        if (!toastNotice) return;
        toastMsg.textContent = text;
        toastNotice.classList.add('show');
        playTone(520, 'sine', 0.1, 0.05);

        if (toastTimeout) clearTimeout(toastTimeout);
        toastTimeout = setTimeout(() => {
            toastNotice.classList.remove('show');
        }, 2600);
    };

    copyActions.forEach((item) => {
        item.addEventListener('click', () => {
            const textToCopy = item.getAttribute('data-copy');
            if (textToCopy) {
                navigator.clipboard.writeText(textToCopy).then(() => {
                    showToast(`Copied "${textToCopy}" to clipboard!`);
                }).catch(() => {
                    showToast(`Copied to clipboard!`);
                });
            }
        });
    });

    /* ==========================================================================
       10. PROJECT CASE STUDY MODAL PREVIEWS
       ========================================================================== */
    const projectModal = document.getElementById('projectModal');
    const modalCloseBtn = document.getElementById('modalCloseBtn');
    const modalBody = document.getElementById('modalBody');

    const projectData = {
        veloce: {
            title: "LABURNUM DEVELOPERS",
            subtitle: "Digital Marketing & Performance Campaigns",
            year: "2025",
            role: "Digital Marketing Specialist",
            description: "High-impact digital marketing strategy and multi-channel lead generation campaigns for premium real estate developments, driving high-intent customer inquiries and brand authority.",
            tech: ["Meta Ads", "Google Ads", "Conversion API", "SEO", "Lead Generation"],
            image: "./project_laburnum.jpg",
            extraSectionTitle: "SEO & TRAFFIC ANALYTICS",
            extraImages: [
                {
                    src: "./laburnum_seo_analytics.png",
                    caption: "Organic Traffic & Keyword Growth (Semrush / Analytics)"
                },
                {
                    src: "./laburnum_seo_blogs.jpg",
                    caption: "Top Performing Blog Articles & SEO Rankings (laburnumdevelopers.com)"
                }
            ],
            externalLink: {
                title: "BLOGS POSTED",
                url: "https://docs.google.com/spreadsheets/d/1oRg4p8EBpRSD9NOzxpw-YtE0Bb1P5kramG03tmd7pi8/edit?gid=0#gid=0"
            }
        },
        woodcraft: {
            title: "TECHHUBX",
            subtitle: "Ad Campaigns & Brand Creatives",
            year: "2024",
            role: "Paid Ads & Creative Strategist",
            description: "Performance ad campaigns with scroll-stopping video ads, high-CTR display creatives, and full-funnel retargeting strategies that significantly boosted conversion rate and ROAS.",
            tech: ["Meta Pixel", "Canva", "Photoshop", "Video Ads", "A/B Testing"],
            image: "./project_techhubx.png",
            extraSectionTitle: "META ADS CAMPAIGNS & CREATIVES",
            extraImages: [
                {
                    src: "./techhubx_meta_ads_dashboard.jpg",
                    caption: "Meta Ads Manager — Messaging Conversions & Low Cost-per-Result (₹11.68 / ₹20.47)"
                },
                {
                    src: "./techhubx_ad_creative_1.jpg",
                    caption: "High-CTR Display Ad Creative — TechHubX 75\" Digital Board Festival Campaign"
                },
                {
                    src: "./techhubx_ad_creative_2.jpg",
                    caption: "Performance Ad Creative — Balaji LNS Smart Digital Board for Online Teaching"
                },
                {
                    src: "./techhubx_ad_creative_3.jpg",
                    caption: "Studio Production Launch Creative — Swar Sagar Podcast Studio"
                }
            ]
        },
        urbanic: {
            title: "MisFIT Club",
            subtitle: "Shopify Website & E-Commerce Growth",
            year: "2024",
            role: "Shopify Designer & Growth Marketer",
            description: "End-to-end modern Shopify e-commerce store design for MisFIT Club activewear, optimized for seamless mobile checkout, high average order value, and repeat retention.",
            tech: ["Shopify", "E-Commerce Strategy", "UI/UX Design", "Social Commerce", "Email Marketing"],
            image: "./project_misfit.png"
        }
    };

    const openProjectModal = (key) => {
        const data = projectData[key];
        if (!data || !modalBody || !projectModal) return;

        const extraImagesHtml = data.extraImages ? `
            <div style="margin-top:14px; display:flex; flex-direction:column; gap:12px; border-top:1px solid rgba(255,255,255,0.08); padding-top:16px;">
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:8px;">
                    <span style="font-size:0.75rem; letter-spacing:0.14em; text-transform:uppercase; color:#ff334b; font-weight:700;">
                        ${data.extraSectionTitle || "CAMPAIGN PERFORMANCE & CREATIVES"}
                    </span>
                    ${data.externalLink ? `
                        <a href="${data.externalLink.url}" target="_blank" rel="noopener noreferrer" style="display:inline-flex; align-items:center; gap:6px; font-size:0.72rem; letter-spacing:0.1em; text-transform:uppercase; color:#ffffff; background:rgba(229,9,20,0.22); border:1px solid rgba(255,31,56,0.55); padding:6px 12px; border-radius:20px; text-decoration:none; font-weight:600; transition:all 0.2s;" onmouseover="this.style.background='#ff1f38'; this.style.borderColor='#ff1f38';" onmouseout="this.style.background='rgba(229,9,20,0.22)'; this.style.borderColor='rgba(255,31,56,0.55)';">
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                            <span>${data.externalLink.title}</span>
                            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="7" y1="17" x2="17" y2="7"></line><polyline points="7 7 17 7 17 17"></polyline></svg>
                        </a>
                    ` : ''}
                </div>
                ${data.extraImages.map(img => `
                    <div style="border-radius:8px; overflow:hidden; border:1px solid rgba(255,255,255,0.1); background:#08080a;">
                        <img src="${img.src}" alt="${img.caption || data.title}" style="width:100%; height:auto; display:block; object-fit:contain;">
                        ${img.caption ? `<div style="padding:8px 12px; font-size:0.72rem; color:#888; background:rgba(0,0,0,0.6); border-top:1px solid rgba(255,255,255,0.06); letter-spacing:0.04em;">${img.caption}</div>` : ''}
                    </div>
                `).join('')}
            </div>
        ` : '';

        modalBody.innerHTML = `
            <div style="display:flex; flex-direction:column; gap:16px;">
                <h2 style="font-size:1.8rem; font-weight:900; letter-spacing:0.04em; text-transform:uppercase; color:#ffffff; line-height:1.1;">
                    ${data.title}
                </h2>
                <div style="font-size:0.85rem; color:#888; text-transform:uppercase; letter-spacing:0.1em; margin-top:-8px;">
                    ${data.subtitle} &bull; <span style="color:#ddd">${data.role}</span>
                </div>
                <div style="width:100%; height:220px; border-radius:6px; overflow:hidden; margin:8px 0; background:#080808; border:1px solid rgba(255,255,255,0.08);">
                    <img src="${data.image}" alt="${data.title}" style="width:100%; height:100%; object-fit:cover;">
                </div>
                <p style="font-size:0.88rem; line-height:1.6; color:#bbb;">
                    ${data.description}
                </p>
                <div style="display:flex; flex-wrap:wrap; gap:8px; margin-top:4px;">
                    ${data.tech.map(t => `<span class="skill-tag" style="font-size:0.65rem;">${t}</span>`).join('')}
                </div>
                ${extraImagesHtml}
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; margin-top:16px; padding-top:16px; border-top:1px solid rgba(255,255,255,0.08);">
                    <a href="#contact" class="primary-cta-btn" onclick="document.getElementById('projectModal').classList.remove('active');" style="padding:10px 20px;">
                        <span>DISCUSS SIMILAR PROJECT</span>
                    </a>
                    ${data.externalLink ? `
                        <a href="${data.externalLink.url}" target="_blank" rel="noopener noreferrer" style="display:inline-flex; align-items:center; gap:8px; color:#ff334b; font-size:0.75rem; letter-spacing:0.12em; text-transform:uppercase; font-weight:700; text-decoration:none;">
                            <span>${data.externalLink.title}</span>
                            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="7" y1="17" x2="17" y2="7"></line><polyline points="7 7 17 7 17 17"></polyline></svg>
                        </a>
                    ` : ''}
                </div>
            </div>
        `;

        projectModal.classList.add('active');
        playTone(720, 'sine', 0.08, 0.04);
    };

    projectCards.forEach((card) => {
        card.addEventListener('click', () => {
            const projKey = card.getAttribute('data-project');
            openProjectModal(projKey);
        });
    });

    if (modalCloseBtn && projectModal) {
        modalCloseBtn.addEventListener('click', () => {
            projectModal.classList.remove('active');
        });
        projectModal.addEventListener('click', (e) => {
            if (e.target === projectModal) {
                projectModal.classList.remove('active');
            }
        });
    }

    const startProjectBtn = document.getElementById('startProjectBtn');
    if (startProjectBtn) {
        startProjectBtn.addEventListener('click', () => {
            const contactSection = document.getElementById('contact');
            if (contactSection) {
                contactSection.scrollIntoView({ behavior: 'smooth' });
                playTone(660, 'sine', 0.1, 0.05);
            }
        });
    }

    const scrollCue = document.getElementById('scrollCue');
    if (scrollCue) {
        scrollCue.addEventListener('click', () => {
            const projectsSection = document.getElementById('projects');
            if (projectsSection) {
                projectsSection.scrollIntoView({ behavior: 'smooth' });
            }
        });
    }
});
