/* ============================================================
   Orbita Games — Web Demos (Math Dash & Star Connect)
   ============================================================ */

const GAME_DEMOS = {
    mathDash: {
        score: 0,
        timer: 100,
        interval: null,
        correctAnswer: 0,
        init() {
            const container = document.getElementById('web-game-container');
            container.innerHTML = `
                <div class="web-game math-dash">
                    <div class="game-hud">
                        <span>BALL: <strong id="md-score">0</strong></span>
                        <div class="progress-bar"><div id="md-timer" style="width:100%"></div></div>
                    </div>
                    <div class="question-box" id="md-question">? + ?</div>
                    <div class="options-grid" id="md-options"></div>
                </div>
            `;
            this.nextQuestion();
            this.startTimer();
        },
        nextQuestion() {
            const a = Math.floor(Math.random() * 10) + 1;
            const b = Math.floor(Math.random() * 10) + 1;
            this.correctAnswer = a + b;
            document.getElementById('md-question').textContent = `${a} + ${b} = ?`;

            const opts = [this.correctAnswer];
            while(opts.length < 4) {
                const f = this.correctAnswer + (Math.floor(Math.random() * 5) + 1) * (Math.random() > 0.5 ? 1 : -1);
                if(f > 0 && !opts.includes(f)) opts.push(f);
            }
            opts.sort(() => Math.random() - 0.5);

            const grid = document.getElementById('md-options');
            grid.innerHTML = '';
            opts.forEach(o => {
                const btn = document.createElement('button');
                btn.className = 'opt-btn';
                btn.textContent = o;
                btn.onclick = () => this.checkAnswer(o);
                grid.appendChild(btn);
            });
            this.timer = 100;
        },
        checkAnswer(val) {
            if(val === this.correctAnswer) {
                this.score += 10;
                document.getElementById('md-score').textContent = this.score;
                this.nextQuestion();
            } else {
                this.gameOver();
            }
        },
        startTimer() {
            this.interval = setInterval(() => {
                this.timer -= 1.5;
                const el = document.getElementById('md-timer');
                if(el) el.style.width = this.timer + '%';
                if(this.timer <= 0) this.gameOver();
            }, 100);
        },
        gameOver() {
            clearInterval(this.interval);
            alert(`O'yin tugadi! Ball: ${this.score}`);
            document.getElementById('game-demo-overlay').classList.remove('open');
        }
    }
};

function openGameDemo(type) {
    const overlay = document.getElementById('game-demo-overlay');
    overlay.classList.add('open');
    if(type === 'math') GAME_DEMOS.mathDash.init();
}

window.openGameDemo = openGameDemo;
