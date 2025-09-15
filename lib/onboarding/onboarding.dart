import 'package:fiberlux_new_app/view/login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modelo para las páginas de onboarding
class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// ViewModel para el onboarding
class OnboardingViewModel extends ChangeNotifier {
  final PageController pageController = PageController(); // Añadido controlador

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: '¡Bienvenido!',
      description:
          'Con la App Mi Fiberlux, tienes toda la información de tu servicio en un solo lugar.',
      imagePath: 'assets/logos/logoFiber.png',
    ),
    OnboardingPage(
      title: 'Revisa tus servicios',
      description:
          'Revisa el estado de tu servicio contratado y disfruta de una mejor experiencia.',
      imagePath: 'assets/icons/icon-1.png',
    ),
    OnboardingPage(
      title: '¡Lleva el control de tus pagos!',
      description:
          'Consulta tus recibos pendientes y el historial de pagos y mantente al día.',
      imagePath: 'assets/icons/icon-2.png',
    ),
  ];

  int _currentPageIndex = 0;

  List<OnboardingPage> get pages => _pages;
  int get currentPageIndex => _currentPageIndex;
  bool get isLastPage => _currentPageIndex == _pages.length - 1;

  void nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      _currentPageIndex++;
      // Animar el PageView al cambiar la página usando el controller
      pageController.animateToPage(
        _currentPageIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentPageIndex > 0) {
      _currentPageIndex--;
      // Animar el PageView al cambiar la página usando el controller
      pageController.animateToPage(
        _currentPageIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }

  void goToPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _currentPageIndex = index;
      notifyListeners();
    }
  }

  // Para marcar que el onboarding ya se ha completado
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
  }

  // Para verificar si el onboarding ya se ha completado
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboardingComplete') ?? false;
  }

  @override
  void dispose() {
    pageController.dispose(); // Importante liberar recursos
    super.dispose();
  }
}

// Vista principal del onboarding
class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: Scaffold(
        body: Consumer<OnboardingViewModel>(
          builder: (context, viewModel, _) {
            return Stack(
              children: [
                // PageView para deslizar entre páginas
                PageView.builder(
                  controller: viewModel
                      .pageController, // Usar el controller del ViewModel
                  itemCount: viewModel.pages.length,
                  onPageChanged: viewModel.goToPage,
                  itemBuilder: (context, index) {
                    final page = viewModel.pages[index];
                    return OnboardingPageView(page: page);
                  },
                ),

                // Botones de navegación en la parte inferior
                Positioned(
                  bottom: 100,
                  left: 20,
                  right: 20,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: ElevatedButton(
                      onPressed: viewModel.isLastPage
                          ? () => _finishOnboarding(context, viewModel)
                          : viewModel.nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 128, 42, 118),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 17,
                        ),
                      ),
                      child: Text(
                        style: TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        'Siguiente',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Método para finalizar el onboarding y navegar a la pantalla principal
  void _finishOnboarding(
    BuildContext context,
    OnboardingViewModel viewModel,
  ) async {
    await viewModel.completeOnboarding();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
}

// Widget para mostrar una página individual del onboarding
class OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;

  const OnboardingPageView({Key? key, required this.page}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Imagen
          Expanded(
            flex: 2,
            child: Image.asset(width: 250, page.imagePath, fit: BoxFit.contain),
          ),

          SizedBox(height: 10),

          // Título
          Text(
            page.title,
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Color.fromARGB(255, 185, 31, 197),
              // color: Color.fromARGB(255, 128, 42, 118),
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 20),

          // Descripción
          Text(
            page.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
              fontFamily: "Poppins",
            ),
            textAlign: TextAlign.center,
          ),

          // Espacio para los indicadores y botones
          Expanded(flex: 1, child: SizedBox()),
        ],
      ),
    );
  }
}

// Widget para los indicadores de página
class PageIndicator extends StatelessWidget {
  final bool isActive;

  const PageIndicator({Key? key, required this.isActive}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
